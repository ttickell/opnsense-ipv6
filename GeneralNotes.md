# General Notes
Moving the internal networks to an ULA will make things easier and more resilient, from everything i can find.

## Questions
1) What happens to dhcp6c startup if I move the LANinterface to Static?
2) The current config for dhcp6c doesn't allocate a PD to the WAN interfaces-does it need to to make Track Interface work?

## ULA To Use
Breaking down a ULA just for me to grok this.

Damn a /48 is a lot of space.

```
fd03:17ac:e938::/48
  fd03:17ac:e938::/50
    fd03:17ac:e938::/52
        fd03:17ac:e938::/56
          fd03:17ac:e938::/58
            fd03:17ac:e938::/60 
            fd03:17ac:e938:10::/60 <-- Home Starts Here
                fd03:17ac:e938:10::/64 <-- LAN (igc2) - Map PD 2, PD 0, 0/4
                fd03:17ac:e938:11::/64 <-- CAM (igc3) - Map PD 3, PD 0, 1/4
                fd03:17ac:e938:12::/64 <-- Wiregaurd  - Map PD 4, PD 0, 2/4
                fd03:17ac:e938:13::/64 <-- OpenVPN    - Map PD 5, PD 0, 3/4
                fd03:17ac:e938:14::/64 <-- Guest Net  - Map PD 6, PD 0, 4/4
                fd03:17ac:e938:15::/64 <-- IOT        - Map PD 7, PD 0, 5/4
                fd03:17ac:e938:16::/64 <-- GAMES      - MAP PD 8, PD 0, 6/4
                fd03:17ac:e938:17::/64
                fd03:17ac:e938:18::/64
                fd03:17ac:e938:19::/64
                fd03:17ac:e938:1a::/64
                fd03:17ac:e938:1b::/64
                fd03:17ac:e938:1c::/64
                fd03:17ac:e938:1d::/64
                fd03:17ac:e938:1e::/64
                fd03:17ac:e938:1f::/64

            fd03:17ac:e938:20::/60
            fd03:17ac:e938:30::/60

          fd03:17ac:e938:40::/58
          fd03:17ac:e938:80::/58
          fd03:17ac:e938:c0::/58

        fd03:17ac:e938:100::/56
        fd03:17ac:e938:200::/56
        fd03:17ac:e938:300::/56
        fd03:17ac:e938:400::/56
        fd03:17ac:e938:500::/56
        fd03:17ac:e938:600::/56
        fd03:17ac:e938:700::/56
        fd03:17ac:e938:800::/56
        fd03:17ac:e938:900::/56
        fd03:17ac:e938:a00::/56
        fd03:17ac:e938:b00::/56
        fd03:17ac:e938:c00::/56
        fd03:17ac:e938:d00::/56
        fd03:17ac:e938:e00::/56
        fd03:17ac:e938:f00::/56

    fd03:17ac:e938:1000::/52
    fd03:17ac:e938:2000::/52
    fd03:17ac:e938:3000::/52

  fd03:17ac:e938:4000::/50
  fd03:17ac:e938:8000::/50
  fd03:17ac:e938:c000::/50
