# Remote deployment script for Azure RunCommand
B64_DATA="[B64_PLACEHOLDER]"
echo "$B64_DATA" > /tmp/scripts.tar.gz.b64
base64 -d /tmp/scripts.tar.gz.b64 > /tmp/scripts.tar.gz
mkdir -p /tmp/extract
tar -xzf /tmp/scripts.tar.gz -C /tmp/extract
sudo mkdir -p /opt/cis
sudo cp -r /tmp/extract/scripts/* /opt/cis/
sudo chmod +x /opt/cis/cis-tool.sh
sudo find /opt/cis -type f -name "*.sh" -exec sed -i 's/\r$//' {} +
echo "Deployment successful"
