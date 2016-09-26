# Weather Service for Data Semi-Cube

## Setup

```
$ sudo apt-get install ruby ruby-dev
$ cd <here>
$ sudo gem install bundler --no-ri --no-rdoc
$ bundle
$ sudo cp weatherd.service /lib/systemd/system/weatherd.service
$ sudo chmod 644 /lib/systemd/system/weatherd.service
$ sudo systemctl daemon-reload
$ sudo systemctl enable weatherd
$ sudo systemctl start weatherd
```

Watch logs with `sudo journalctl -fu weatherd`
