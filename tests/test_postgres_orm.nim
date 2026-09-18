import std/[asyncdispatch, os, unittest]
import jazzy

const postgresTestDsn = "JAZZY_POSTGRES_TEST_DSN"

model PgComment:
  table "jazzy_orm_comments"
  id int64
  postId int64, column = "post_id"
  body string

model PgPost:
  table "jazzy_orm_posts"
  id int64
  userId int64, column = "user_id"
  title string
  hasMany comments, PgComment, foreignKey = "postId"

model PgRole:
  table "jazzy_orm_roles"
  id int64
  name string

model PgProfile:
  table "jazzy_orm_profiles"
  id int64
  userId int64, column = "user_id"
  bio string

model PgUser:
  table "jazzy_orm_users"
  id int64
  name string
  hasMany posts, PgPost, foreignKey = "userId"
  hasOne profile, PgProfile, foreignKey = "userId"
  belongsToMany roles, PgRole,
    through = "jazzy_orm_user_roles", foreignKey = "user_id", relatedKey = "role_id"

model PgPostWithAuthor:
  table "jazzy_orm_posts"
  id int64
  userId int64, column = "user_id"
  title string
  belongsTo author, PgUser, foreignKey = "userId"

model PgAccount:
  table "jazzy_orm_accounts"
  uuid string, column = "account_uuid", primaryKey = true
  displayName string, column = "display_name"
  bio Option[string]

proc exerciseOrm(): Future[void] {.async.} =
  discard await DB.rawExec("DROP TABLE IF EXISTS jazzy_orm_user_roles")
  discard await DB.rawExec("DROP TABLE IF EXISTS jazzy_orm_comments")
  discard await DB.rawExec("DROP TABLE IF EXISTS jazzy_orm_posts")
  discard await DB.rawExec("DROP TABLE IF EXISTS jazzy_orm_profiles")
  discard await DB.rawExec("DROP TABLE IF EXISTS jazzy_orm_roles")
  discard await DB.rawExec("DROP TABLE IF EXISTS jazzy_orm_users")
  discard await DB.rawExec("DROP TABLE IF EXISTS jazzy_orm_accounts")
  discard await DB.rawExec("""
    CREATE TABLE jazzy_orm_users (
      id BIGSERIAL PRIMARY KEY,
      name TEXT NOT NULL
    )
  """)
  discard await DB.rawExec("""
    CREATE TABLE jazzy_orm_posts (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT NOT NULL REFERENCES jazzy_orm_users(id),
      title TEXT NOT NULL
    )
  """)
  discard await DB.rawExec("""
    CREATE TABLE jazzy_orm_comments (
      id BIGSERIAL PRIMARY KEY,
      post_id BIGINT NOT NULL REFERENCES jazzy_orm_posts(id),
      body TEXT NOT NULL
    )
  """)
  discard await DB.rawExec("""
    CREATE TABLE jazzy_orm_roles (
      id BIGSERIAL PRIMARY KEY,
      name TEXT NOT NULL
    )
  """)
  discard await DB.rawExec("""
    CREATE TABLE jazzy_orm_profiles (
      id BIGSERIAL PRIMARY KEY,
      user_id BIGINT NOT NULL UNIQUE REFERENCES jazzy_orm_users(id),
      bio TEXT NOT NULL
    )
  """)
  discard await DB.rawExec("""
    CREATE TABLE jazzy_orm_user_roles (
      user_id BIGINT NOT NULL REFERENCES jazzy_orm_users(id),
      role_id BIGINT NOT NULL REFERENCES jazzy_orm_roles(id)
    )
  """)
  discard await DB.rawExec("""
    CREATE TABLE jazzy_orm_accounts (
      account_uuid UUID PRIMARY KEY,
      display_name TEXT NOT NULL,
      bio TEXT NULL
    )
  """)

  let ada = await PgUser.create(PgUser(name: "Ada"))
  let post = await PgPost.create(PgPost(userId: ada.id, title: "Notes"))
  discard await post.createRelated("comments", PgComment(body: "cached"))
  discard await ada.createRelated("profile", PgProfile(bio: "First programmer"))
  let admin = await PgRole.create(PgRole(name: "admin"))
  check (await ada.attach("roles", admin.id))

  let eager = await PgUser.with("posts.comments", "profile", "roles").get()
  check eager.len == 1
  let eagerPosts = await eager[0].posts()
  check eagerPosts.len == 1
  check (await eagerPosts[0].comments()).len == 1
  discard await DB.rawExec("UPDATE jazzy_orm_comments SET body = 'changed'")
  check (await eagerPosts[0].comments())[0].body == "cached"
  check (await eager[0].profile()).isSome
  check (await eager[0].roles())[0].name == "admin"
  check (await ada.sync("roles", [admin.id])) == 0
  check (await ada.detach("roles", admin.id)) == 1

  let owner = await (await PgPostWithAuthor.find(post.id)).get().author()
  check owner.isSome
  check owner.get().id == ada.id

  let account = await PgAccount.create(PgAccount(
    uuid: "6a4177e1-dc3a-4a94-8e80-24993846205a", displayName: "Deploy",
    bio: none(string)
  ))
  check account.bio.isNone
  let changed = await PgAccount.patch(account.uuid, %*{"bio": "production"})
  check changed.isSome
  check changed.get().bio.get() == "production"

  discard await DB.rawExec("DROP TABLE jazzy_orm_user_roles")
  discard await DB.rawExec("DROP TABLE jazzy_orm_comments")
  discard await DB.rawExec("DROP TABLE jazzy_orm_posts")
  discard await DB.rawExec("DROP TABLE jazzy_orm_profiles")
  discard await DB.rawExec("DROP TABLE jazzy_orm_roles")
  discard await DB.rawExec("DROP TABLE jazzy_orm_users")
  discard await DB.rawExec("DROP TABLE jazzy_orm_accounts")

suite "PostgreSQL ORM":
  test "supports mapped fields, nullable values, and eager relations":
    let dsn = getEnv(postgresTestDsn)
    if dsn.len == 0:
      skip()
    else:
      putEnv("DB_CONNECTION", "postgres")
      putEnv("DATABASE_URL", dsn)
      putEnv("DB_POOL_MIN", "1")
      putEnv("DB_POOL_MAX", "2")
      configureDatabase()
      waitFor exerciseOrm()
      waitFor closePostgresForWorker()
