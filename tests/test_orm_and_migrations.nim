import std/[asyncdispatch, options, times, unittest]
import jazzy

type MembershipState = enum
  invited, activeMember

model OrmUser:
  table "orm_users"
  id int64
  name string
  active bool
  timestamps()

model MappedAccount:
  table "orm_accounts"
  uuid string, column = "account_uuid", primaryKey = true
  displayName string, column = "display_name"
  bio Option[string]

model TypedMembership:
  table "typed_memberships"
  id int64
  state MembershipState
  joinedAt DateTime, column = "joined_at"

model RelationComment:
  table "relation_comments"
  id int64
  postId int64, column = "post_id"
  body string

model RelationPost:
  table "relation_posts"
  id int64
  userId int64, column = "user_id"
  title string
  hasMany comments, RelationComment, foreignKey = "postId"

model RelationRole:
  table "relation_roles"
  id int64
  name string

model RelationProfile:
  table "relation_profiles"
  id int64
  userId int64, column = "user_id"
  bio string

model RelationUser:
  table "relation_users"
  id int64
  name string
  scope namedAda:
    where "name", "Ada"
  hasMany posts, RelationPost, foreignKey = "userId"
  hasOne profile, RelationProfile, foreignKey = "userId"
  belongsToMany roles, RelationRole,
    through = "relation_user_roles", foreignKey = "user_id", relatedKey = "role_id"

model RelationPostWithUser:
  table "relation_posts"
  id int64
  userId int64, column = "user_id"
  title string
  belongsTo author, RelationUser, foreignKey = "userId"

migration "20260917120000_create_orm_users":
  up:
    await createTable("orm_users")
      .increments("id")
      .string("name")
      .boolean("active", default = false)
      .timestamps()
      .execute()
  down:
    discard await DB.rawExec("DROP TABLE \"orm_users\"")

seed "20260917120100_demo_audit":
  discard await DB.table("seed_audit").insert(%*{"message": "seeded"})

proc dropLegacyColumnUp(): Future[void] {.async.} =
  await alterTable("migration_drop_column_test")
    .dropColumn("legacy_note")
    .execute()

proc dropLegacyColumnDown(): Future[void] {.async.} =
  await alterTable("migration_drop_column_test")
    .addString("legacy_note", nullable = true)
    .execute()

suite "Jazzy migrations and ORM":
  setup:
    connectDB(":memory:")

  teardown:
    closeDB()

  test "runs transactional migrations and reports their state":
    check (waitFor migrate(@[jazzyMigration])) == 1
    check (waitFor migrate(@[jazzyMigration])) == 0
    let status = waitFor migrationStatus()
    check status.len == 1
    check status[0].name == "20260917120000_create_orm_users"
    check status[0].batch == 1
    check (waitFor rollback(@[jazzyMigration])) == 1
    check (waitFor migrationStatus()).len == 0

  test "supports pending previews, step batches, reset, and fresh":
    let pending = waitFor pendingMigrations(@[jazzyMigration])
    check pending.len == 1
    check pending[0].name == "20260917120000_create_orm_users"
    check (waitFor migrateStep(@[jazzyMigration])) == 1
    check (waitFor migrationStatus())[0].batch == 1
    check (waitFor reset(@[jazzyMigration])) == 1
    check (waitFor migrationStatus()).len == 0
    check (waitFor migrate(@[jazzyMigration])) == 1
    check (waitFor fresh(@[jazzyMigration])) == 1
    check (waitFor migrationStatus()).len == 1

  test "drops and restores a column inside a SQLite migration transaction":
    waitFor createTable("migration_drop_column_test")
      .increments("id")
      .string("name")
      .string("legacy_note", nullable = true)
      .execute()
    discard waitFor DB.table("migration_drop_column_test").insert(%*{
      "name": "Ada", "legacy_note": "old value"
    })
    let migration = initMigration("20260917120200_drop_legacy_note",
      dropLegacyColumnUp, dropLegacyColumnDown)

    check (waitFor migrate(@[migration])) == 1
    let changed = waitFor DB.table("migration_drop_column_test").first()
    check not changed.hasKey("legacy_note")

    check (waitFor rollback(@[migration])) == 1
    check "legacy_note" in (waitFor getColumns("migration_drop_column_test"))
    let restored = waitFor DB.table("migration_drop_column_test").first()
    check restored.hasKey("legacy_note")

  test "runs explicit seeders in deterministic order":
    discard waitFor DB.rawExec("CREATE TABLE seed_audit (message TEXT NOT NULL)")
    check (waitFor seedAll(@[jazzySeeder])) == 1
    let rows = waitFor DB.raw("SELECT message FROM seed_audit")
    check rows.len == 1
    check rows[0]["message"].getStr() == "seeded"

  test "maps a single-block model to awaited CRUD":
    discard waitFor migrate(@[jazzyMigration])
    let created = waitFor OrmUser.create(OrmUser(name: "Ada", active: true))
    check created.id == 1
    check created.name == "Ada"
    check created.active
    check created.created_at.len > 0

    let found = waitFor OrmUser.find(created.id)
    check found.isSome
    check found.get().name == "Ada"

    let users = waitFor OrmUser.where("active", true).orderBy("id", "DESC").get()
    check users.len == 1
    check users[0].id == created.id

    let changed = waitFor OrmUser.update(created.id,
      OrmUser(name: "Grace", active: false))
    check changed.isSome
    check changed.get().name == "Grace"
    check not changed.get().active
    check (waitFor OrmUser.delete(created.id)) == 1
    check (waitFor OrmUser.all()).len == 0

  test "supports nullable fields, mapped columns, custom keys, and patches":
    discard waitFor DB.rawExec("""
      CREATE TABLE orm_accounts (
        account_uuid TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        bio TEXT NULL
      )
    """)
    let created = waitFor MappedAccount.create(MappedAccount(
      uuid: "a-uuid-1", displayName: "Ada", bio: none(string)
    ))
    check created.uuid == "a-uuid-1"
    check created.displayName == "Ada"
    check created.bio.isNone

    let found = waitFor MappedAccount.where("displayName", "Ada").first()
    check found.isSome
    let changed = waitFor MappedAccount.patch("a-uuid-1", %*{
      "displayName": "Ada Lovelace", "bio": "First programmer"
    })
    check changed.isSome
    check changed.get().displayName == "Ada Lovelace"
    check changed.get().bio.get() == "First programmer"
    check (waitFor MappedAccount.find("a-uuid-1")).isSome
    check (waitFor MappedAccount.where("uuid", "a-uuid-1").patch(%*{
      "bio": "Updated from a query"
    })) == 1
    check (waitFor MappedAccount.whereNotIn("displayName", ["Nobody"]).count()) == 1

  test "casts native enum and DateTime fields through the model":
    discard waitFor DB.rawExec("""
      CREATE TABLE typed_memberships (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        state TEXT NOT NULL,
        joined_at TEXT NOT NULL
      )
    """)
    let joinedAt = dateTime(2026, mSep, 17, 14, 30, 0, 123_000_000, utc())
    let created = waitFor TypedMembership.create(TypedMembership(
      state: activeMember, joinedAt: joinedAt
    ))
    check created.state == activeMember
    check created.joinedAt.format(ormDateTimeFormat) == joinedAt.format(ormDateTimeFormat)
    let found = waitFor TypedMembership.find(created.id)
    check found.isSome
    check found.get().state == activeMember

  test "loads relations in batches and provides scopes and pagination":
    discard waitFor DB.rawExec("""
      CREATE TABLE relation_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    """)
    discard waitFor DB.rawExec("""
      CREATE TABLE relation_posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL
      )
    """)
    discard waitFor DB.rawExec("""
      CREATE TABLE relation_roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    """)
    discard waitFor DB.rawExec("""
      CREATE TABLE relation_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE,
        bio TEXT NOT NULL
      )
    """)
    discard waitFor DB.rawExec("""
      CREATE TABLE relation_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL,
        body TEXT NOT NULL
      )
    """)
    discard waitFor DB.rawExec("""
      CREATE TABLE relation_user_roles (
        user_id INTEGER NOT NULL,
        role_id INTEGER NOT NULL
      )
    """)

    let ada = waitFor RelationUser.create(RelationUser(name: "Ada"))
    let grace = waitFor RelationUser.create(RelationUser(name: "Grace"))
    let firstPost = waitFor RelationPost.create(RelationPost(
      userId: ada.id, title: "Analytical Engine"))
    discard waitFor firstPost.createRelated("comments", RelationComment(
      body: "Original eager-loaded comment"))
    discard waitFor ada.createRelated("posts", RelationPost(title: "Notes"))
    discard waitFor RelationPost.create(RelationPost(
      userId: grace.id, title: "Compiler"))
    let admin = waitFor RelationRole.create(RelationRole(name: "admin"))
    let editor = waitFor RelationRole.create(RelationRole(name: "editor"))
    discard waitFor ada.createRelated("profile", RelationProfile(
      bio: "First programmer"))
    check waitFor ada.attach("roles", admin.id)
    check not (waitFor ada.attach("roles", admin.id))
    check waitFor ada.attach("roles", editor.id)

    check (waitFor ada.posts()).len == 2
    let profile = waitFor ada.profile()
    check profile.isSome
    check profile.get().bio == "First programmer"
    let post = (waitFor RelationPostWithUser.find(firstPost.id)).get()
    let author = waitFor post.author()
    check author.isSome
    check author.get().name == "Ada"

    let eager = waitFor RelationUser.with("posts.comments", "profile", "roles")
      .orderBy("id").get()
    check eager.len == 2
    let eagerPosts = waitFor eager[0].posts()
    check eagerPosts.len == 2
    check (waitFor eagerPosts[0].comments()).len == 1
    discard waitFor DB.rawExec("UPDATE relation_comments SET body = 'Changed after eager load'")
    check (waitFor eagerPosts[0].comments())[0].body == "Original eager-loaded comment"
    check (waitFor eager[0].profile()).isSome
    check (waitFor eager[0].roles()).len == 2

    check (waitFor ada.sync("roles", [editor.id])) == 1
    check (waitFor ada.roles()).len == 1
    check (waitFor ada.roles())[0].name == "editor"
    check (waitFor ada.detach("roles", editor.id)) == 1
    check (waitFor ada.roles()).len == 0

    let scoped = waitFor RelationUser.namedAda().get()
    check scoped.len == 1
    check scoped[0].id == ada.id

    let page = waitFor RelationUser.where("id", ">", 0)
      .orderBy("id").paginate(page = 1, perPage = 1)
    check page.total == 2
    check page.data.len == 1
    check page.lastPage == 2

  test "builds drafts and persists typed factories":
    discard waitFor migrate(@[jazzyMigration])
    let draft = OrmUser.make(proc(): OrmUser =
      OrmUser(name: "Draft", active: false)
    )
    check draft.id == 0
    let users = waitFor OrmUser.factory(2, proc(index: int): OrmUser =
      OrmUser(name: "Factory " & $index, active: true)
    )
    check users.len == 2
    check users[0].id > 0
    check (waitFor OrmUser.where("active", true).count()) == 2

  test "tracks dirty fields, saves only changes, and invokes lifecycle hooks":
    discard waitFor migrate(@[jazzyMigration])
    var beforeCreates = 0
    var afterCreates = 0
    var beforeUpdates = 0
    var afterUpdates = 0
    var beforeDeletes = 0
    var afterDeletes = 0
    OrmUser.beforeCreate(proc(value: var OrmUser) =
      inc beforeCreates
      value.name = "Created " & value.name
    )
    OrmUser.afterCreate(proc(value: OrmUser) =
      inc afterCreates
      check value.name == "Created Ada"
    )
    OrmUser.beforeUpdate(proc(value: var OrmUser) =
      inc beforeUpdates
      value.name = "Updated " & value.name
    )
    OrmUser.afterUpdate(proc(value: OrmUser) =
      inc afterUpdates
      check value.name == "Updated Grace"
    )
    OrmUser.beforeDelete(proc(id: int64) =
      inc beforeDeletes
    )
    OrmUser.afterDelete(proc(id: int64) =
      inc afterDeletes
    )

    var user = waitFor OrmUser.create(OrmUser(name: "Ada", active: true))
    check user.name == "Created Ada"
    check beforeCreates == 1
    check afterCreates == 1
    check not user.isDirty
    user.name = "Grace"
    check user.isDirty
    check user.isDirty("name")
    check user.dirty == @["name"]
    user = waitFor user.save()
    check user.name == "Updated Grace"
    check not user.isDirty
    check beforeUpdates == 1
    check afterUpdates == 1
    check (waitFor OrmUser.delete(user.id)) == 1
    check beforeDeletes == 1
    check afterDeletes == 1
