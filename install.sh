#!/bin/bash
set -e

GO_VERSION="1.22.3"
GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
EXPECTED_CHECKSUM="8920ea521bad8f6b7bc377b4824982e011c19af27df88a815e3586ea895f1b36"

# Log output of script
exec > >(tee -i /home/admin/install.log)
exec 2>&1

echo "Updating package manager and installing necessary packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y git make

# Set home and cache directories
export HOME=/home/admin
export GOCACHE=$HOME/.cache

if ! go version | grep -q "${GO_VERSION}" ; then
  echo "Downloading and installing Go..."
  # Download the Go binary
  curl -OL ${GO_URL}
  # Verify the checksum
  ACTUAL_CHECKSUM=$(sha256sum go${GO_VERSION}.linux-amd64.tar.gz | awk '{print $1}')
  if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    echo "Checksum verification failed. Aborting installation."
    exit 1
  fi
  # Remove existing Go installation if it exists
  if [ -d "/usr/local/go" ]; then
    sudo rm -rf /usr/local/go
  fi
  # Extract the tarball
  sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
  # Remove the downloaded tarball
  rm go${GO_VERSION}.linux-amd64.tar.gz
  echo "Setting up Go environment..."
  # Add Go to the PATH environment variable for ubuntu user
  if ! grep -q 'export PATH=$PATH:/usr/local/go/bin' /home/admin/.profile ; then
    echo "export PATH=\$PATH:/usr/local/go/bin" >> /home/admin/.profile
  fi
  # Add Go to the PATH environment variable for current script
  export PATH=$PATH:/usr/local/go/bin
else
  echo "Go version ${GO_VERSION} already installed, skipping installation."
fi

# Uncomment if you are using evilginx as the dns resolver 
#echo "Modifying systemd-resolved configuration..."
#sudo sed -i 's/#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
#sudo systemctl restart systemd-resolved

# Uncomment if you are using evilginx as the dns resolver 
#echo "Setting permissions to allow evilginx to bind to privileged ports..."
#sudo setcap CAP_NET_BIND_SERVICE=+eip evilginx

echo "Cloning evilginx repository..."
if [ ! -d "/home/admin/src-evilginx" ]; then
    git clone https://github.com/kgretzky/evilginx2 /home/admin/src-evilginx
fi

echo "Building evilginx repository..."
cd /home/admin/src-evilginx
go build
make

echo "Setting up evilginx directory..."
mkdir -p /home/admin/evilginx
cp /home/admin/src-evilginx/build/evilginx /home/admin/evilginx/
cd /home/admin/evilginx
mkdir -p phishlets redirectors

# Comment to prevent blocking MSFT ASN space
echo "Setting up evilginx EOP blacklist..."
cd /root/.evilginx/
sudo wget -O blacklist.txt wget https://github.com/aalex954/MSFT-IP-Tracker/releases/latest/download/msft_asn_ip_ranges.txt

echo "Removing the src-evilginx directory"
rm -rf /home/admin/src-evilginx

echo "Done"
exit 0
