import struct, lzma, zlib, gzip, hashlib, sys, io
src = sys.argv[1]; out = sys.argv[2]
img = open(src,'rb').read()
f = list(struct.unpack('<8s10I', img[:48]))
ksz, page = f[1], f[8]
k = img[page:page+ksz]
d = zlib.decompressobj(16+15); fd = bytearray(d.decompress(k)); dtb = d.unused_data
CO = 53408                              # LZMA data inside outer GUIDed section
SEC = 53384; FFS = 53360
oldsec = fd[SEC] | fd[SEC+1]<<8 | fd[SEC+2]<<16
inner = bytearray(lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(bytes(fd[CO:SEC+oldsec])))
DS = 5178128
L = struct.unpack('<I', inner[DS+4:DS+8])[0]
dsdt = bytearray(inner[DS:DS+L])
patches = [
  # USB-C sink PDOs: 5V/3A, 9V/2A, 12V/1.5A  ->  5V/3A, 9V/3A, 12V/1.5A  (27 W max, tablet rated 33 W)
  (bytes.fromhex('0c2c9101000cc8d002000c96c00300'), bytes.fromhex('0c2c9101000c2cd102000c96c00300')),
  # BPCH {HVDCP 2100, HVDCPv3 3000, IWall 1500} -> IWall 3000
  (bytes.fromhex('0b34080bb80b0bdc05'), bytes.fromhex('0b34080bb80b0bb80b')),
]
for a,b in patches:
    assert dsdt.count(a) == 1 and len(a) == len(b); i = dsdt.find(a); dsdt[i:i+len(a)] = b
dsdt[9] = 0; dsdt[9] = (-sum(dsdt)) & 0xff
assert sum(dsdt) & 0xff == 0
inner[DS:DS+L] = dsdt
filt = [{'id': lzma.FILTER_LZMA1, 'dict_size': 1<<24, 'lc':3, 'lp':0, 'pb':2, 'preset': 9|lzma.PRESET_EXTREME}]
comp = bytearray(lzma.compress(bytes(inner), format=lzma.FORMAT_ALONE, filters=filt))
comp[5:13] = struct.pack('<Q', len(inner))
assert lzma.LZMADecompressor(format=lzma.FORMAT_ALONE).decompress(bytes(comp)) == bytes(inner)
oldffs = fd[FFS+20] | fd[FFS+21]<<8 | fd[FFS+22]<<16
secsz = 24 + len(comp); ffssz = 24 + secsz
newsec = bytearray(fd[SEC:SEC+24]); newsec[0:3] = secsz.to_bytes(3,'little')
hdr = bytearray(fd[FFS:FFS+24]); hdr[20:23] = ffssz.to_bytes(3,'little')
hdr[16] = 0; hdr[17] = 0; st = hdr[23]; hdr[23] = 0
hdr[16] = (-sum(hdr)) & 0xff; hdr[17] = 0xAA; hdr[23] = st
body = bytes(hdr) + bytes(newsec) + bytes(comp)
end_old = FFS + oldffs
FV = 112; fvlen = struct.unpack('<Q', fd[FV+32:FV+40])[0]
rest = fd[end_old:FV+fvlen]
assert rest == b'\xff'*len(rest), 'outer FV has more files after the compressed one'
newfv = fd[:FFS] + body
newfv += b'\xff' * (FV+fvlen - len(newfv))
assert len(newfv) == FV+fvlen
fd2 = newfv + fd[FV+fvlen:]
assert len(fd2) == len(fd)
gz = io.BytesIO()
with gzip.GzipFile(filename='SILICIUM_UEFI.fd', mode='wb', fileobj=gz, mtime=0) as g: g.write(fd2)
kern = gz.getvalue() + dtb
f[1] = len(kern)
hdrimg = bytearray(img[:page]); hdrimg[0:48] = struct.pack('<8s10I', *f)
pad = lambda x: x + b'\0'*((-len(x)) % page)
rest_img = img[page + ((ksz + page - 1)//page)*page:]
newimg = bytes(hdrimg) + pad(kern) + rest_img
open(out,'wb').write(newimg)
print('dsdt sha', hashlib.sha256(dsdt).hexdigest()[:16], 'comp', len(comp), 'img', len(newimg), 'sha256', hashlib.sha256(newimg).hexdigest())
