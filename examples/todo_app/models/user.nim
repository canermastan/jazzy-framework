import jazzy

model User:
  table "users"
  id int64
  username string
  passwordHash string, column = "password"
  timestamps()
