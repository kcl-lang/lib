const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

export function encodeVarint(value: bigint): Uint8Array {
  const bytes: number[] = [];
  let v = value;
  while (v >= 0x80n) {
    bytes.push(Number(v & 0x7fn) | 0x80);
    v >>= 7n;
  }
  bytes.push(Number(v));
  return new Uint8Array(bytes);
}

function tag(field: number, wireType: number): Uint8Array {
  return encodeVarint(BigInt((field << 3) | wireType));
}

export function stringField(
  field: number,
  value: string | undefined
): Uint8Array {
  if (!value) {
    return new Uint8Array(0);
  }
  return bytesField(field, textEncoder.encode(value));
}

export function boolField(field: number, value: boolean): Uint8Array {
  if (!value) {
    return new Uint8Array(0);
  }
  return concatBytes(tag(field, 0), encodeVarint(1n));
}

export function int64Field(field: number, value: number | bigint): Uint8Array {
  if (value === 0 || value === 0n) {
    return new Uint8Array(0);
  }
  let v = BigInt(value);
  if (v < 0n) {
    v = (1n << 64n) + v;
  }
  return concatBytes(tag(field, 0), encodeVarint(v));
}

export function bytesField(field: number, value: Uint8Array): Uint8Array {
  if (value.length === 0) {
    return new Uint8Array(0);
  }
  return concatBytes(tag(field, 2), encodeVarint(BigInt(value.length)), value);
}

export function concatBytes(...parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const p of parts) {
    out.set(p, offset);
    offset += p.length;
  }
  return out;
}

export class ProtoReader {
  private readonly buf: Uint8Array;
  private pos = 0;

  constructor(bytes: Uint8Array) {
    this.buf = bytes;
  }

  get eof(): boolean {
    return this.pos >= this.buf.length;
  }

  readTag(): number {
    return Number(this.readVarint());
  }

  readVarint(): bigint {
    let result = 0n;
    let shift = 0n;
    for (;;) {
      if (this.pos >= this.buf.length) {
        throw new Error("truncated protobuf varint");
      }
      const b = this.buf[this.pos++];
      result |= BigInt(b & 0x7f) << shift;
      if ((b & 0x80) === 0) {
        return result;
      }
      shift += 7n;
      if (shift > 70n) {
        throw new Error("protobuf varint too long");
      }
    }
  }

  readBool(): boolean {
    return this.readVarint() !== 0n;
  }

  readString(): string {
    return textDecoder.decode(this.readBytes());
  }

  readBytes(): Uint8Array {
    const len = Number(this.readVarint());
    if (this.pos + len > this.buf.length) {
      throw new Error("truncated protobuf field");
    }
    const out = this.buf.slice(this.pos, this.pos + len);
    this.pos += len;
    return out;
  }

  readMessage(): ProtoReader {
    return new ProtoReader(this.readBytes());
  }

  readInt64(): number {
    return Number(this.readSignedVarint());
  }

  readUint64(): number {
    return Number(this.readVarint());
  }

  private readSignedVarint(): bigint {
    let v = this.readVarint();
    if (v >= 1n << 63n) {
      v -= 1n << 64n;
    }
    return v;
  }

  skip(wireType: number): void {
    switch (wireType) {
      case 0:
        this.readVarint();
        break;
      case 1:
        this.pos += 8;
        break;
      case 2: {
        const len = Number(this.readVarint());
        this.pos += len;
        break;
      }
      case 5:
        this.pos += 4;
        break;
      default:
        throw new Error(`unsupported protobuf wire type ${wireType}`);
    }
    if (this.pos > this.buf.length) {
      throw new Error("truncated protobuf field");
    }
  }
}
