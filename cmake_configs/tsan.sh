set -e

mkdir -p build/tsan
cd build/tsan
# For sanitizer builds clang needs to be used
export CLANG=$KUDU_HOME/build-support/ccache-clang/clang
time ( \
CC=${CLANG} CXX=${CLANG}++ ../../thirdparty/installed/common/bin/cmake \
  -DCMAKE_BUILD_TYPE=fastdebug \
  -DKUDU_LINK=dynamic\
  -DKUDU_USE_TSAN=1 \
  -GNinja \
  ../.. \
&& ninja )