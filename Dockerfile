# docker build -t dots .
# docker run -itv $PWD:/app dots
# docker build --build-arg IMAGE=debian -t dots .
# docker build --build-arg IMAGE=fedora -t dots .

ARG IMAGE=alpine

FROM $IMAGE

WORKDIR /app
VOLUME /app

RUN command -v bash || (\
    command -v apk && apk add bash\
  )

RUN \
  --mount=target=. \
  ls -la \
  && bash -c "source bootstrap.sh"

CMD ["bash", "-c", "source bootstrap.sh; bash"]
