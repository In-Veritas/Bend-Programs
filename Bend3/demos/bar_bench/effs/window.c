//! link -framework Cocoa -framework QuartzCore
// win_open(w, h, title) -> IO<U32>   create the window and canvas; 1 ok
// win_frame(cmds)       -> IO<U32>   rasterize the command list, present,
//                                    pump events; returns the key pressed
//                                    since the last frame (ASCII, 0 none,
//                                    'q' if the window was closed)
// win_close()           -> IO<U32>   tear the window down; 0
//
// The GPU does not make windows anywhere -- the OS window server does.
// This effect is Bend's sanctioned door to it: pure C, quarantined behind
// the IO protocol like every other effect. Bend computes the animation
// (all F32 physics stays in the pure fragment); this side only rasterizes
// draw commands into an RGBX canvas and hands it to Cocoa.
//
// Command stream, flat u32s (all y coordinates carry a +1000 bias so the
// pure side never builds a negative number):
//   0 rgb                        clear canvas
//   1 x y+1000 w h rgb           filled rect (clipped)
//   2 x y+1000 scale digit rgb   3x5 digit glyph, digit 0..9
//
// Cocoa from plain C: objc_msgSend with per-signature casts (mandatory on
// arm64), CoreGraphics for the bitmap, a manual event pump instead of
// [NSApp run] so the io event loop stays in charge.

#include <objc/runtime.h>
#include <objc/message.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreFoundation/CoreFoundation.h>

typedef id (*msg_id)(id, SEL);
typedef id (*msg_id_id)(id, SEL, id);
typedef id (*msg_id_ptr)(id, SEL, const void*);
typedef void (*msg_void)(id, SEL);
typedef void (*msg_void_id)(id, SEL, id);
typedef void (*msg_void_bool)(id, SEL, bool);
typedef bool (*msg_bool)(id, SEL);
typedef long (*msg_long)(id, SEL);
typedef bool (*msg_bool_long)(id, SEL, long);
typedef id (*msg_win_init)(id, SEL, CGRect, unsigned long, unsigned long, bool);
typedef id (*msg_next_event)(id, SEL, unsigned long, id, id, bool);

// the host recipe may compile this as ObjC+ARC (Metal) or plain C (CPU):
// bridge casts only exist under ARC, and Foundation may already be included
extern void* objc_autoreleasePoolPush(void);
extern void objc_autoreleasePoolPop(void* pool);

#ifdef __OBJC__
#define WIN_ID(x) ((__bridge id)(x))
#else
#define WIN_ID(x) ((id)(x))
#endif

static id win_app = NULL;
static id win_win = NULL;
static id win_layer = NULL;
static unsigned char* win_fb = NULL;
static u32 win_w = 0;
static u32 win_h = 0;
static u32 win_key_seen = 0;

static id win_cls(const char* name) {
  return (id)objc_getClass(name);
}

static SEL win_sel(const char* name) {
  return sel_registerName(name);
}

static Term io_win_open(State st, Term wT, Term hT, Term title) {
  if (win_win != NULL) {
    return W32(1);
  }
  void* pool = objc_autoreleasePoolPush();
  win_w = (u32)term_loc(wT);
  win_h = (u32)term_loc(hT);
  if (win_w == 0 || win_w > 4096 || win_h == 0 || win_h > 4096) {
    return W32(0);
  }
  // (opened before the pool so an early return needs no pop)
  win_fb = (unsigned char*)calloc((size_t)win_w * win_h, 4);
  if (win_fb == NULL) {
    return W32(0);
  }
  u64 tlen = 0;
  char* tstr = io_str_read(st, title, &tlen);

  win_app = ((msg_id)objc_msgSend)(win_cls("NSApplication"), win_sel("sharedApplication"));
  ((msg_bool_long)objc_msgSend)(win_app, win_sel("setActivationPolicy:"), 0 /* regular */);
  CGRect frame = CGRectMake(0, 0, (CGFloat)win_w, (CGFloat)win_h);
  id win = ((msg_id)objc_msgSend)(win_cls("NSWindow"), win_sel("alloc"));
  win = ((msg_win_init)objc_msgSend)(win, win_sel("initWithContentRect:styleMask:backing:defer:"),
                                     frame, 1 | 2 | 4 /* titled|closable|mini */, 2 /* buffered */, false);
  ((msg_void_bool)objc_msgSend)(win, win_sel("setReleasedWhenClosed:"), false);
  id nstitle = ((msg_id_ptr)objc_msgSend)(win_cls("NSString"), win_sel("stringWithUTF8String:"), tstr);
  free(tstr);
  ((msg_void_id)objc_msgSend)(win, win_sel("setTitle:"), nstitle);
  ((msg_void)objc_msgSend)(win, win_sel("center"));
  id view = ((msg_id)objc_msgSend)(win, win_sel("contentView"));
  ((msg_void_bool)objc_msgSend)(view, win_sel("setWantsLayer:"), true);
  win_layer = ((msg_id)objc_msgSend)(view, win_sel("layer"));
  ((msg_void_id)objc_msgSend)(win, win_sel("makeKeyAndOrderFront:"), NULL);
  ((msg_void_bool)objc_msgSend)(win_app, win_sel("activateIgnoringOtherApps:"), true);
  ((msg_void)objc_msgSend)(win_app, win_sel("finishLaunching"));
  win_win = win;
  win_key_seen = 0;
  objc_autoreleasePoolPop(pool);
  return W32(1);
}

// ---- rasterizer ------------------------------------------------------

static void win_px(long x, long y, u32 rgb) {
  if (x < 0 || y < 0 || x >= (long)win_w || y >= (long)win_h) {
    return;
  }
  unsigned char* p = win_fb + ((size_t)y * win_w + (size_t)x) * 4;
  p[0] = (rgb >> 16) & 0xFF;
  p[1] = (rgb >> 8) & 0xFF;
  p[2] = rgb & 0xFF;
  p[3] = 0xFF;
}

static void win_rect(long x, long y, long w, long h, u32 rgb) {
  for (long j = 0; j < h; j++) {
    for (long i = 0; i < w; i++) {
      win_px(x + i, y + j, rgb);
    }
  }
}

// 3x5 digit font, one u16 per glyph, rows top-down, 3 bits per row
static unsigned short win_glyph(u32 d) {
  switch (d) {
    case 0: return 075557; // 111 101 101 101 111
    case 1: return 026227; // 010 110 010 010 111
    case 2: return 071747; // 111 001 111 100 111
    case 3: return 071717; // 111 001 111 001 111
    case 4: return 055711; // 101 101 111 001 001
    case 5: return 074717; // 111 100 111 001 111
    case 6: return 074757; // 111 100 111 101 111
    case 7: return 071111; // 111 001 001 001 001
    case 8: return 075757; // 111 101 111 101 111
    default: return 075717; // 111 101 111 001 111
  }
}

static void win_digit(long x, long y, long s, u32 d, u32 rgb) {
  unsigned short g = win_glyph(d % 10);
  for (long r = 0; r < 5; r++) {
    u32 row = (g >> ((4 - r) * 3)) & 7;
    for (long c = 0; c < 3; c++) {
      if (row & (1u << (2 - c))) {
        win_rect(x + c * s, y + r * s, s, s, rgb);
      }
    }
  }
}

// ---- present + events ------------------------------------------------

// BEND_WIN_DUMP=<prefix>: also write every 40th frame as <prefix>NNNN.ppm
// (P6), so the canvas is verifiable without screen-capture permissions
static void win_dump(void) {
  static u32 counter = 0;
  const char* prefix = getenv("BEND_WIN_DUMP");
  if (prefix == NULL || (counter++ % 40) != 0) {
    return;
  }
  char path[1024];
  snprintf(path, sizeof(path), "%s%04u.ppm", prefix, counter - 1);
  FILE* f = fopen(path, "wb");
  if (f == NULL) {
    return;
  }
  fprintf(f, "P6\n%u %u\n255\n", win_w, win_h);
  for (size_t i = 0; i < (size_t)win_w * win_h; i++) {
    fwrite(win_fb + i * 4, 1, 3, f);
  }
  fclose(f);
}

static void win_present(State st) {
  win_dump();
  CFDataRef data = CFDataCreate(NULL, win_fb, (CFIndex)win_w * win_h * 4);
  CGDataProviderRef prov = CGDataProviderCreateWithCFData(data);
  CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
  CGImageRef img = CGImageCreate(win_w, win_h, 8, 32, (size_t)win_w * 4, cs,
                                 kCGImageAlphaNoneSkipLast, prov, NULL, false,
                                 kCGRenderingIntentDefault);
  ((msg_void_id)objc_msgSend)(win_layer, win_sel("setContents:"), WIN_ID(img));
  ((msg_void)objc_msgSend)(win_cls("CATransaction"), win_sel("flush"));
  CGImageRelease(img);
  CGColorSpaceRelease(cs);
  CGDataProviderRelease(prov);
  CFRelease(data);
}

static void win_pump(void) {
  id past = ((msg_id)objc_msgSend)(win_cls("NSDate"), win_sel("distantPast"));
  id mode = ((msg_id_ptr)objc_msgSend)(win_cls("NSString"), win_sel("stringWithUTF8String:"),
                                       "kCFRunLoopDefaultMode");
  for (;;) {
    id e = ((msg_next_event)objc_msgSend)(win_app,
             win_sel("nextEventMatchingMask:untilDate:inMode:dequeue:"),
             ~0UL, past, mode, true);
    if (e == NULL) {
      break;
    }
    long type = ((msg_long)objc_msgSend)(e, win_sel("type"));
    if (type == 10 /* keyDown */) {
      id chars = ((msg_id)objc_msgSend)(e, win_sel("charactersIgnoringModifiers"));
      if (chars != NULL) {
        const char* c = ((const char* (*)(id, SEL))objc_msgSend)(chars, win_sel("UTF8String"));
        if (c != NULL && c[0] != 0) {
          win_key_seen = (u32)(unsigned char)c[0];
        }
      }
    } else {
      ((msg_void_id)objc_msgSend)(win_app, win_sel("sendEvent:"), e);
    }
  }
}

static Term io_win_frame(State st, Term cmds) {
  void* pool = objc_autoreleasePoolPush();
  // walk the List<U32> (List::Cons is the same ctor strings use; the
  // elements here are raw words, not Char wrappers)
  u32 buf[4096];
  u32 n = 0;
  Term cur = cmds;
  while (term_tag(cur) == CTR && term_cid(cur) == IO_STR_CONS) {
    Term head;
    Term rest;
    alloc_drop(st, term_ctr_take_2(st, cur, &head, &rest), 2);
    if (n < 4096) {
      buf[n++] = (u32)term_loc(head);
    }
    cur = rest;
  }
  if (win_win == NULL || win_fb == NULL) {
    objc_autoreleasePoolPop(pool);
    return W32('q');
  }
  u32 i = 0;
  while (i < n) {
    u32 op = buf[i++];
    if (op == 0 && i + 1 <= n) {
      u32 rgb = buf[i++];
      for (size_t p = 0; p < (size_t)win_w * win_h; p++) {
        unsigned char* q = win_fb + p * 4;
        q[0] = (rgb >> 16) & 0xFF;
        q[1] = (rgb >> 8) & 0xFF;
        q[2] = rgb & 0xFF;
        q[3] = 0xFF;
      }
    } else if (op == 1 && i + 5 <= n) {
      long x = (long)buf[i];
      long y = (long)buf[i + 1] - 1000;
      long w = (long)buf[i + 2];
      long h = (long)buf[i + 3];
      u32 rgb = buf[i + 4];
      i += 5;
      win_rect(x, y, w, h, rgb);
    } else if (op == 2 && i + 5 <= n) {
      long x = (long)buf[i];
      long y = (long)buf[i + 1] - 1000;
      long s = (long)buf[i + 2];
      u32 d = buf[i + 3];
      u32 rgb = buf[i + 4];
      i += 5;
      win_digit(x, y, s, d, rgb);
    } else {
      break;
    }
  }
  win_present(st);
  win_pump();
  bool visible = ((msg_bool)objc_msgSend)(win_win, win_sel("isVisible"));
  objc_autoreleasePoolPop(pool);
  if (!visible) {
    return W32('q');
  }
  u32 k = win_key_seen;
  win_key_seen = 0;
  return W32(k);
}

static Term io_win_close(State st) {
  void* pool = objc_autoreleasePoolPush();
  if (win_win != NULL) {
    ((msg_void_id)objc_msgSend)(win_win, win_sel("close"), NULL);
    win_pump();
    win_win = NULL;
    win_layer = NULL;
  }
  if (win_fb != NULL) {
    free(win_fb);
    win_fb = NULL;
  }
  objc_autoreleasePoolPop(pool);
  return W32(0);
}
