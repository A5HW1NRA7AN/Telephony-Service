FROM ghcr.io/patrickbaus/freeswitch-docker:master

# Remove the default configurations provided by the base image
RUN rm -rf /etc/freeswitch/*

# Create directory for custom greeting sounds
RUN mkdir -p /usr/share/freeswitch/sounds/custom

# Copy greeting audio into the container
COPY greeting.wav /usr/share/freeswitch/sounds/custom/greeting.wav
COPY audio/*.wav /usr/share/freeswitch/sounds/custom/

# Expose SIP UDP/TCP and Event Socket Library (ESL)
EXPOSE 5060/udp 5060/tcp
EXPOSE 8021/tcp

CMD ["freeswitch", "-nonat", "-ncwait", "-c"]
