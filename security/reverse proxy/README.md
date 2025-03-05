# Reverse Proxy

## Public

Cloudflare DNS nameservers

Add port forwarding only [Cloudflare IP addresses](https://www.cloudflare.com/en-au/ips/) through your firewall.
This enforces users to go through cloudflare encase they discover your public IP address.
It is better to do this on your routers firewall, however no all routers allow for this. Therefore you can do this on your servers firewall. You'll need to do this for allow nodes in your cluster!
```sh
sudo ufw status
sudo ufw allow from 103.21.244.0/22
sudo ufw delete allow from 103.21.244.0/22
sudo ufw allow 22/tcp
sudo ufw delete allow 22/tcp
```

Cloudflare also has firewall rules to block countries, TOR and list of known bad IP addresses.

UDM Pro, pf sense (snort / suricata) to detect and block known bad IP addresses.

Block dark web

Cloudflare also has;
- DDoS attack protection (automatically enabled)
- WAF (Also configures cloudflare firewall here)
- Rate Limiting
- DNSSEC (DNS proxied through cloudflare otherwise by adding DS record to your registrar)
```sh
DS RECORD:
pumptown2025.com. 3600 IN DS 2371 13 2 FD8B69AAF2BAD846615A7DEA23F885274898E5D97E3EAACFCDC5B0B54642143C

DIGEST:
FD8B69AAF2BAD846615A7DEA23F885274898E5D97E3EAACFCDC5B0B54642143C

Digest Type - 2:
SHA256

Algorithm:
13

Public Key:
mdsswUyr3DPW132mOi8V9xESWE8jTo0dxCjjnopKl+GqJxpVXckHAeF+KkxLbxILfDLUT0rAK9iUzy1L53eKGQ==

Key Tag:
2371

Flags:
257 (KSK)
```

## Private

Traefik to route request to servers and retrieve public signed certificates.

Store certificates here.

Consider 2FA authelia as reverse proxy middleware for certain apps.
