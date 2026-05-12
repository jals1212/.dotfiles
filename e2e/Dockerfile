FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    git curl sudo build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy dotfiles repo structure
COPY dots-binary /usr/local/bin/dots
COPY home /opt/dotfiles/home
COPY assets /opt/dotfiles/assets
COPY e2e/e2e_test.sh /home/testuser/e2e_test.sh
RUN chmod +x /usr/local/bin/dots /home/testuser/e2e_test.sh

ENV DOTFILES_DIR=/opt/dotfiles

USER testuser
WORKDIR /home/testuser

CMD ["./e2e_test.sh"]
