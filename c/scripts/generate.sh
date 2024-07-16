git clone https://github.com/nanopb/nanopb.git
cd nanopb
grep -v '^package' ../../../spec/gpyrpc/spec.proto > "spec.proto"
sed -i '' -e 's|string default |string default_ |g' spec.proto

python3 generator/nanopb_generator.py spec.proto

# Copy headers
cp pb_common.h ../../include/pb_common.h
cp pb_decode.h ../../include/pb_decode.h
cp pb_encode.h ../../include/pb_encode.h
cp pb.h ../../include/pb.h
cp spec.pb.h ../../include/spec.pb.h

# Copy impls
cp pb_common.c ../../lib/pb_common.c
cp pb_decode.c ../../lib/pb_decode.c
cp pb_encode.c ../../lib/pb_encode.c
cp spec.pb.c ../../lib/spec.pb.c

cd ..
rm -rf nanopb
