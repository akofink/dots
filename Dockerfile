# docker build -t dots .
# docker run -itv $PWD:/app dots
ARG IMAGE=alpine
FROM $IMAGE
WORKDIR /app
VOLUME /app
CMD ["sh", "-c", "source setup.sh; sh"]
