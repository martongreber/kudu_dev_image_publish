#!/bin/bash

# exit when any command fails, to avoid long hanging job
set -e
build_arch=$(uname -m)
build_types=("dev" "kudu-thirdparty" "kudu-thirdparty-all" "kudu-debug" "kudu-release" "kudu-asan" "kudu-tsan")
cache_for_type=("" "dev" "kudu-thirdparty" "kudu-thirdparty" "kudu-thirdparty" "kudu-thirdparty-all" "kudu-thirdparty-all")
builder_name="insecure_builder"
username="murculus"

# Define a timestamp function
timestamp() {
  date +"%T" # current time
}

build-and-publish() {

  docker login
  docker system prune -a -f
  docker system prune -a -f --volumes

  set +e
  docker buildx inspect $builder_name
  builder_inspect=$?
  set -e
  if [ $builder_inspect -eq 0 ]; then
    echo "$(timestamp) LOG: removing builder: $builder_name as it already exists"
    docker buildx rm $builder_name
  fi
  # https://stackoverflow.com/questions/48098671/build-with-docker-and-privileged
  docker buildx create --driver-opt image=moby/buildkit:master  \
                      --use --name $builder_name \
                      --buildkitd-flags '--allow-insecure-entitlement security.insecure' \
                      --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=-1 --driver-opt env.BUILDKIT_STEP_LOG_MAX_SPEED=-1

  docker buildx use $builder_name

  echo "$(timestamp) LOG: pwd: $(pwd)"

  cache_switches=""
  for index in "${!build_types[@]}"
  do
      build_type=${build_types[$index]}
      echo "$(timestamp) LOG: creating cache switches at build stage $build_type:$build_arch"
      if [ ! -z "${cache_for_type[$index]}" ]; then
        cache_switches=" --cache-from=type=registry,ref=$username/${cache_for_type[$index]}:$build_arch"
      else
        cache_switches=""
      fi
      cache_switches+=" --cache-from=type=registry,ref=$username/$build_type:$build_arch"
      echo "$(timestamp) LOG: cache switches: $cache_switches"

      echo "$(timestamp) LOG: starting image build: $build_type:$build_arch"
      set -x
      time docker buildx build --push \
                              --allow security.insecure \
                              --cache-to=type=inline \
                              $cache_switches \
                              --target $build_type \
                              -t murculus/$build_type:$build_arch .
      set +x
      echo "$(timestamp) LOG: finished image build: $build_type:$build_arch"

      #update the manifest
      # echo "$(timestamp) LOG: starting updating the manifest, latest tag: $build_type:$build_arch"
      # set +e
      # docker manifest create \
      #   $username/$build_type:latest \
      #   --amend $username/$build_type:x86_64 \
      #   --amend $username/$build_type:aarch64
      # docker manifest push $username/$build_type:latest
      # set -e
      # echo "$(timestamp) LOG: finished updating the manifest, latest tag: $build_type:$build_arch"

  done

  docker buildx rm $builder_name

  echo "$(timestamp) LOG: finished"
}

SOURCE_ROOT=$(cd $(dirname "$BASH_SOURCE"); pwd)
cd $SOURCE_ROOT

DATE=`date +%d-%m-%y`
build-and-publish > /tmp/build-and-publish-$DATE.log 2>&1

