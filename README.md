# cidr

Tiny command-line tool that calculate CIDR.

## Build / Installation

```shell
zig build
```

## Usage / Example

```shell
$ cidr 10.0.0.0/18

CIDR calculation result
==============================================
Input         : 10.0.0.0/18
CIDR          : 10.0.0.0/18
NetMask       : 255.255.192.0
IP Range      : 10.0.0.0 - 10.0.63.255
Available IPs : 16384
```

## License

MIT License

## Author

Yoshiaki Sugimoto
