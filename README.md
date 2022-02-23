# kortleser2


## Nix
Get the libraries and script:
```
nix-build -A omnikey
./result/read-omnikey
```

## Ubuntu

```
apt install pcscd

cat <<<EOF | sudo tee /etc/default/read-omnikey
OMNIKEY_WEBHOOK_URL=http://ha.lan.folkeverkstedet.com:8123/api/webhook/some-uuid
EOF

cat <<<EOF | sudo tee /etc/systemd/system/read-omnikey.service
[Unit]
Description=read-omnikey

[Service]
Type=simple
User=fv
Group=fv
EnvironmentFile=/etc/default/read-omnikey
ExecStart=/home/fv/src/kortleser2/read-omnikey.pl
Restart=on-failure
SyslogIdentifier=read-omnikey.pl

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable read-omnikey
systemctl start read-omnikey
```
