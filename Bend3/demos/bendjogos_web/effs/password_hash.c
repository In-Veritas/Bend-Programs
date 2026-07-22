// password_hash(password, salt) -> IO<String>
// PBKDF2-HMAC-SHA-256, 60,000 rounds, one 32-byte block rendered as hex.
#include <stdint.h>

typedef struct {
  uint8_t data[64];
  uint32_t used;
  uint64_t bits;
  uint32_t state[8];
} PasswordSha256;

static const uint32_t password_sha256_k[64] = {
  0x428a2f98u,0x71374491u,0xb5c0fbcfu,0xe9b5dba5u,0x3956c25bu,0x59f111f1u,0x923f82a4u,0xab1c5ed5u,
  0xd807aa98u,0x12835b01u,0x243185beu,0x550c7dc3u,0x72be5d74u,0x80deb1feu,0x9bdc06a7u,0xc19bf174u,
  0xe49b69c1u,0xefbe4786u,0x0fc19dc6u,0x240ca1ccu,0x2de92c6fu,0x4a7484aau,0x5cb0a9dcu,0x76f988dau,
  0x983e5152u,0xa831c66du,0xb00327c8u,0xbf597fc7u,0xc6e00bf3u,0xd5a79147u,0x06ca6351u,0x14292967u,
  0x27b70a85u,0x2e1b2138u,0x4d2c6dfcu,0x53380d13u,0x650a7354u,0x766a0abbu,0x81c2c92eu,0x92722c85u,
  0xa2bfe8a1u,0xa81a664bu,0xc24b8b70u,0xc76c51a3u,0xd192e819u,0xd6990624u,0xf40e3585u,0x106aa070u,
  0x19a4c116u,0x1e376c08u,0x2748774cu,0x34b0bcb5u,0x391c0cb3u,0x4ed8aa4au,0x5b9cca4fu,0x682e6ff3u,
  0x748f82eeu,0x78a5636fu,0x84c87814u,0x8cc70208u,0x90befffau,0xa4506cebu,0xbef9a3f7u,0xc67178f2u
};

static uint32_t password_rotr(uint32_t x, uint32_t n) {
  return (x >> n) | (x << (32u - n));
}

static void password_sha256_transform(PasswordSha256* ctx) {
  uint32_t w[64];
  for (uint32_t i = 0; i < 16; ++i) {
    uint32_t j = i * 4;
    w[i] = ((uint32_t)ctx->data[j] << 24) |
           ((uint32_t)ctx->data[j + 1] << 16) |
           ((uint32_t)ctx->data[j + 2] << 8) |
           (uint32_t)ctx->data[j + 3];
  }
  for (uint32_t i = 16; i < 64; ++i) {
    uint32_t s0 = password_rotr(w[i - 15], 7) ^ password_rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
    uint32_t s1 = password_rotr(w[i - 2], 17) ^ password_rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
    w[i] = w[i - 16] + s0 + w[i - 7] + s1;
  }
  uint32_t a = ctx->state[0];
  uint32_t b = ctx->state[1];
  uint32_t c = ctx->state[2];
  uint32_t d = ctx->state[3];
  uint32_t e = ctx->state[4];
  uint32_t f = ctx->state[5];
  uint32_t g = ctx->state[6];
  uint32_t h = ctx->state[7];
  for (uint32_t i = 0; i < 64; ++i) {
    uint32_t s1 = password_rotr(e, 6) ^ password_rotr(e, 11) ^ password_rotr(e, 25);
    uint32_t choose = (e & f) ^ ((~e) & g);
    uint32_t t1 = h + s1 + choose + password_sha256_k[i] + w[i];
    uint32_t s0 = password_rotr(a, 2) ^ password_rotr(a, 13) ^ password_rotr(a, 22);
    uint32_t majority = (a & b) ^ (a & c) ^ (b & c);
    uint32_t t2 = s0 + majority;
    h = g;
    g = f;
    f = e;
    e = d + t1;
    d = c;
    c = b;
    b = a;
    a = t1 + t2;
  }
  ctx->state[0] += a;
  ctx->state[1] += b;
  ctx->state[2] += c;
  ctx->state[3] += d;
  ctx->state[4] += e;
  ctx->state[5] += f;
  ctx->state[6] += g;
  ctx->state[7] += h;
}

static void password_sha256_init(PasswordSha256* ctx) {
  ctx->used = 0;
  ctx->bits = 0;
  ctx->state[0] = 0x6a09e667u;
  ctx->state[1] = 0xbb67ae85u;
  ctx->state[2] = 0x3c6ef372u;
  ctx->state[3] = 0xa54ff53au;
  ctx->state[4] = 0x510e527fu;
  ctx->state[5] = 0x9b05688cu;
  ctx->state[6] = 0x1f83d9abu;
  ctx->state[7] = 0x5be0cd19u;
}

static void password_sha256_update(PasswordSha256* ctx, const uint8_t* data, size_t len) {
  for (size_t i = 0; i < len; ++i) {
    ctx->data[ctx->used++] = data[i];
    if (ctx->used == 64) {
      password_sha256_transform(ctx);
      ctx->bits += 512;
      ctx->used = 0;
    }
  }
}

static void password_sha256_final(PasswordSha256* ctx, uint8_t out[32]) {
  uint32_t used = ctx->used;
  ctx->data[used++] = 0x80;
  if (used > 56) {
    while (used < 64) {
      ctx->data[used++] = 0;
    }
    password_sha256_transform(ctx);
    used = 0;
  }
  while (used < 56) {
    ctx->data[used++] = 0;
  }
  ctx->bits += (uint64_t)ctx->used * 8u;
  for (uint32_t i = 0; i < 8; ++i) {
    ctx->data[63 - i] = (uint8_t)(ctx->bits >> (i * 8));
  }
  password_sha256_transform(ctx);
  for (uint32_t i = 0; i < 8; ++i) {
    out[i * 4] = (uint8_t)(ctx->state[i] >> 24);
    out[i * 4 + 1] = (uint8_t)(ctx->state[i] >> 16);
    out[i * 4 + 2] = (uint8_t)(ctx->state[i] >> 8);
    out[i * 4 + 3] = (uint8_t)ctx->state[i];
  }
}

static void password_sha256(const uint8_t* data, size_t len, uint8_t out[32]) {
  PasswordSha256 ctx;
  password_sha256_init(&ctx);
  password_sha256_update(&ctx, data, len);
  password_sha256_final(&ctx, out);
}

static void password_hmac(const uint8_t* key, size_t key_len, const uint8_t* data, size_t len, uint8_t out[32]) {
  uint8_t reduced[32];
  uint8_t block[64];
  if (key_len > 64) {
    password_sha256(key, key_len, reduced);
    key = reduced;
    key_len = 32;
  }
  memset(block, 0, sizeof(block));
  memcpy(block, key, key_len);
  for (uint32_t i = 0; i < 64; ++i) {
    block[i] ^= 0x36;
  }
  PasswordSha256 inner;
  password_sha256_init(&inner);
  password_sha256_update(&inner, block, 64);
  password_sha256_update(&inner, data, len);
  password_sha256_final(&inner, out);
  for (uint32_t i = 0; i < 64; ++i) {
    block[i] ^= 0x36 ^ 0x5c;
  }
  PasswordSha256 outer;
  password_sha256_init(&outer);
  password_sha256_update(&outer, block, 64);
  password_sha256_update(&outer, out, 32);
  password_sha256_final(&outer, out);
}

static void password_pbkdf2(const uint8_t* password, size_t len, uint32_t salt, uint8_t out[32]) {
  uint8_t input[8] = {
    (uint8_t)(salt >> 24), (uint8_t)(salt >> 16), (uint8_t)(salt >> 8), (uint8_t)salt,
    0, 0, 0, 1
  };
  uint8_t word[32];
  password_hmac(password, len, input, sizeof(input), word);
  memcpy(out, word, 32);
  for (uint32_t round = 1; round < 60000; ++round) {
    password_hmac(password, len, word, sizeof(word), word);
    for (uint32_t i = 0; i < 32; ++i) {
      out[i] ^= word[i];
    }
  }
}

static Term io_password_hash(State st, Term password_term, Term salt_term) {
  u64 len = 0;
  char* password = io_str_read(st, password_term, &len);
  uint8_t digest[32];
  password_pbkdf2((const uint8_t*)password, (size_t)len, (uint32_t)term_loc(salt_term), digest);
  volatile uint8_t* wipe = (volatile uint8_t*)password;
  for (u64 i = 0; i < len; ++i) {
    wipe[i] = 0;
  }
  free(password);
  static const char hex[] = "0123456789abcdef";
  char text[65];
  for (uint32_t i = 0; i < 32; ++i) {
    text[i * 2] = hex[digest[i] >> 4];
    text[i * 2 + 1] = hex[digest[i] & 15];
  }
  text[64] = 0;
  return io_str_make(st, text, 64);
}
