FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    git curl sudo build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

COPY dots /usr/local/bin/dots
RUN chmod +x /usr/local/bin/dots

COPY e2e/e2e_test.sh /home/testuser/e2e_test.sh
RUN chmod +x /home/testuser/e2e_test.sh

USER testuser
WORKDIR /home/testuser

CMD ["./e2e_test.sh"]
