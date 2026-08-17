# Adapter for the two older command-list window demos.
#
# Bend3's current install has a fixed IO.Op and a standard GFX effect. The
# demos still produce their compact command stream in pure Bend; this module
# rasterizes it into GFX's Image and translates GFX events back to their old
# U32 controls. A depth-9 image gives 2x2 display pixels, keeping this fallback
# substantially lighter than a full 1024x1024 quadtree.

import ../bend-base/Base
import ../bend-base/IO/GFX

def CommandGFX.inside(value: U32, start: U32, size: U32) -> U32:
  (value >= start) && (value < (start + size))

def CommandGFX.glyph(code: U32) -> U32:
  match code:
    case 0: 31599
    case 1: 11415
    case 2: 29671
    case 3: 29647
    case 4: 23497
    case 5: 31183
    case 6: 31215
    case 7: 29257
    case 8: 31727
    case 9: 31695
    case 10: 27566
    case 11: 31143
    case 12: 31597
    case 13: 27502
    case _: 9346

def CommandGFX.glyph_pixel(pattern: U32, x: U32, y: U32, gx: U32, gy: U32, scale: U32) -> U32:
  match CommandGFX.inside(x, gx, scale * 3) && CommandGFX.inside(y, gy, scale * 5):
    case 0:
      0
    case _:
      column = (x - gx) / scale
      row = (y - gy) / scale
      (pattern >> ((((4 - row) * 3) + 2) - column)) .&. 1

def CommandGFX.pixel(cmds: List(U32), x: U32, y: U32, color: U32) -> U32:
  match cmds:
    case List.Nil{}:
      color
    case List.Cons{op, rest}:
      match op:
        case 0:
          match rest:
            case List.Cons{rgb, tail}:
              CommandGFX.pixel(tail, x, y, rgb)
            case List.Nil{}:
              color
        case 1:
          match rest:
            case List.Cons{rx, List.Cons{yb, List.Cons{width, List.Cons{height, List.Cons{rgb, tail}}}}}:
              match CommandGFX.inside(x, rx, width) && CommandGFX.inside(y + 1000, yb, height):
                case 0:
                  CommandGFX.pixel(tail, x, y, color)
                case _:
                  CommandGFX.pixel(tail, x, y, rgb)
            case _:
              color
        case 2:
          match rest:
            case List.Cons{gx, List.Cons{gyb, List.Cons{scale, List.Cons{glyph, List.Cons{rgb, tail}}}}}:
              match CommandGFX.glyph_pixel(CommandGFX.glyph(glyph), x, y + 1000, gx, gyb, scale):
                case 0:
                  CommandGFX.pixel(tail, x, y, color)
                case _:
                  CommandGFX.pixel(tail, x, y, rgb)
            case _:
              color
        case _:
          color

def CommandGFX.image(cmds: List(U32)) -> Image:
  GFX.from_fn(9, x => y => CommandGFX.pixel(cmds, x * 2, y * 2, 0))

def CommandGFX.key_event(events: List(GFX.Event)) -> U32:
  match events:
    case List.Nil{}:
      0
    case List.Cons{event, rest}:
      match event:
        case GFX.Event.Key{code, down}:
          match down:
            case Bool.T{}: code
            case Bool.F{}: CommandGFX.key_event(rest)
        case GFX.Event.Close{}:
          113
        case _:
          CommandGFX.key_event(rest)

def CommandGFX.panel_click(x: U32, y: U32) -> U32:
  match CommandGFX.inside(y, 76, 152):
    case 0:
      match CommandGFX.inside(y, 240, 152):
        case 0:
          0
        case _:
          match CommandGFX.inside(x, 12, 300):
            case 0:
              match CommandGFX.inside(x, 328, 300):
                case 0: 0
                case _: 256 + ((4 * (((y - 240) * 300) + (x - 328))) + 3)
            case _:
              256 + ((4 * (((y - 240) * 300) + (x - 12))) + 2)
    case _:
      match CommandGFX.inside(x, 12, 300):
        case 0:
          match CommandGFX.inside(x, 328, 300):
            case 0: 0
            case _: 256 + ((4 * (((y - 76) * 300) + (x - 328))) + 1)
        case _:
          256 + (4 * (((y - 76) * 300) + (x - 12)))

def CommandGFX.panel_event(events: List(GFX.Event)) -> U32:
  match events:
    case List.Nil{}:
      0
    case List.Cons{event, rest}:
      match event:
        case GFX.Event.Key{code, down}:
          match down:
            case Bool.T{}: code
            case Bool.F{}: CommandGFX.panel_event(rest)
        case GFX.Event.Mouse{x, y, btn, down}:
          match down:
            case Bool.F{}:
              CommandGFX.panel_event(rest)
            case Bool.T{}:
              match btn:
                case 0:
                  match CommandGFX.panel_click(x, y):
                    case 0: CommandGFX.panel_event(rest)
                    case click: click
                case _:
                  CommandGFX.panel_event(rest)
        case GFX.Event.Close{}:
          113
        case _:
          CommandGFX.panel_event(rest)

def CommandGFX.open(title: String, width: U32, height: U32) -> IO(U32):
  do IO(U32):
    GFX.window(title, width, height)
    return 1

def CommandGFX.frame_key(cmds: List(U32)) -> IO(U32):
  do IO(U32):
    GFX.blit(CommandGFX.image(cmds))
    events <- GFX.events()
    return CommandGFX.key_event(events)

def CommandGFX.frame_panel(cmds: List(U32)) -> IO(U32):
  do IO(U32):
    GFX.blit(CommandGFX.image(cmds))
    events <- GFX.events()
    return CommandGFX.panel_event(events)

def CommandGFX.close() -> IO(U32):
  IO.pure(U32, 0)
