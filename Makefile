# Copyright 2019 Tuxera Oy. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

VERSION ?= dev
#REPO=quay.io/tuxera/moosefs-csi-plugin
#REPO?=docker.io/samcv/moosefs-csi
REPO?=docker.io/steffenblake/moosefs-csi-plugin
TARGET?=build
NAME=moosefs-csi-plugin

all: $(TARGET)

build: clean cred test go-compile

publish: build docker-build push-image

cred:
	@echo "==> Scanning secrets in commit history (prevent accidents)"
	# trufflehog --regex --entropy=False --rules scripts/truffleHogRegexes.json  file:///$(shell pwd)
	trufflehog --regex --entropy=False file:///$(shell pwd)

go-compile:
	@echo "==> Building the project"
	@env CGO_ENABLED=0 GOCACHE=/tmp/go-cache GOOS=linux GOARCH=amd64 go build -a -o cmd/${NAME}/${NAME}-amd64 cmd/${NAME}/main.go
	@env CGO_ENABLED=0 GOCACHE=/tmp/go-cache GOOS=linux GOARCH=arm64 go build -a -o cmd/${NAME}/${NAME}-arm64v8 cmd/${NAME}/main.go

test:
	@echo "==> Running tests"
	go test -v ./driver/...

docker-build:
	@echo "==> Building the docker images"
	@docker build -t $(DOCKER_REPO):$(VERSION)-amd64 -t $(DOCKER_REPO):latest-amd64 cmd/${NAME} --build-arg ARCH=amd64
	@docker build -t $(DOCKER_REPO):$(VERSION)-arm64v8 -t $(DOCKER_REPO):latest-arm64v8 cmd/${NAME} --build-arg ARCH=arm64v8
	
	@docker manifest create \
		$(DOCKER_REPO):$(VERSION) \
		--amend $(DOCKER_REPO):$(VERSION)-amd64 \
		--amend $(DOCKER_REPO):$(VERSION)-arm64v8

	@docker manifest create \
		$(DOCKER_REPO):latest \
		--amend $(DOCKER_REPO):latest-amd64 \
		--amend $(DOCKER_REPO):latest-arm64v8


push-image:
	@echo "==> Publishing docker images"
	@docker push $(DOCKER_REPO):$(VERSION)-amd64
	@docker push $(DOCKER_REPO):latest-amd64
	@docker push $(DOCKER_REPO):$(VERSION)-arm64v8
	@docker push $(DOCKER_REPO):latest-arm64v8

	@docker manifest push $(DOCKER_REPO):$(VERSION)
	@docker manifest push $(DOCKER_REPO):latest

	@echo "==> Your images are now available at $(DOCKER_REPO):$(VERSION)/latest"

clean:
	@echo "==> Cleaning releases"
	@GOOS=linux go clean -i -x ./...

.PHONY: all push fetch build-image clean

# Builds moosefs-master, moosefs-chunk
# TODO(anoop): To be moved upstream
push-mfs-master:
	@echo "==> Building the quay.io/tuxera/moosefs-master docker image"
	@docker build -t quay.io/tuxera/moosefs-master:$(VERSION) -f moosefs-master.Dockerfile .
	@docker build -t quay.io/tuxera/moosefs-master:latest -f moosefs-master.Dockerfile .
	@echo "==> Publishing quay.io/tuxera/moosefs-master:$(VERSION)"
	@docker push quay.io/tuxera/moosefs-master:$(VERSION)
	@docker push quay.io/tuxera/moosefs-master:latest
	@echo "==> Your image is now available at quay.io/tuxera/moosefs-master:$(VERSION)/latest"

push-mfs-chunk:
	@echo "==> Building the quay.io/tuxera/moosefs-chunk docker image"
	@docker build -t quay.io/tuxera/moosefs-chunk:$(VERSION) -f moosefs-chunk.Dockerfile .
	@docker build -t quay.io/tuxera/moosefs-chunk:latest -f moosefs-chunk.Dockerfile .
	@echo "==> Publishing quay.io/tuxera/moosefs-chunk:$(VERSION)"
	@docker push quay.io/tuxera/moosefs-chunk:$(VERSION)
	@docker push quay.io/tuxera/moosefs-chunk:latest
	@echo "==> Your image is now available at quay.io/tuxera/moosefs-chunk:$(VERSION)/latest"

push-mfs-client:
	@echo "==> Building the quay.io/tuxera/moosefs-client docker image"
	@docker build -t quay.io/tuxera/moosefs-client:$(VERSION) -f moosefs-client.Dockerfile .
	@docker build -t quay.io/tuxera/moosefs-client:latest -f moosefs-client.Dockerfile .
	@echo "==> Publishing quay.io/tuxera/moosefs-client:$(VERSION)"
	@docker push quay.io/tuxera/moosefs-client:$(VERSION)
	@docker push quay.io/tuxera/moosefs-client:latest
	@echo "==> Your image is now available at quay.io/tuxera/moosefs-client:$(VERSION)/latest"
