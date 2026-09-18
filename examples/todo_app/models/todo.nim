import jazzy

model Todo:
  table "todos"
  id int64
  title string
  completed bool
  timestamps()
