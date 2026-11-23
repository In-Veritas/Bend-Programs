import Base

def choose_io(b: Bool, f: Bool -> IO(Unit)) -> IO(Unit):
  f(b)

law continue_write:
  for result: File & Result<(U32 & String), Unit>
  for continue: File -> IO(Unit)
  IO(Unit)

def continue_write(result, continue):
  match result:
    case Tuple{next_file, status}:
      match status:
        case Done{unit}:
          continue(next_file)
        case Fail{error}:
          File.close(next_file)

law walk:
  for items: List<U32>
  for file: File
  IO(Unit)

def walk(items, file):
  match items:
    case Nil{}:
      File.close(file)
    case Con{head, tail}:
      choose_io(U32.is_eq(head, 0), \{
        True: (
          do IO<Unit>:
            result: File & Result<(U32 & String), Unit> <- File.write(file, "x")
            continue_write(result, next_file => walk(tail, next_file))
        )
        False: walk(tail, file)
      })
