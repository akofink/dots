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

CMD ["bash", "-c", "source bootstrap.sh; bash"]
