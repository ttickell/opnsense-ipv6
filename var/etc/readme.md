# /var/etc/dhcp6c.conf.custom
/var/etc/dhcp6c.conf seems to be what is used by Opnsense when it starts dhcp6c.  While there's an option to override with a custom configuration, in practice it looks /var/etc/dhcp6c.conf is overwritten by by the file specific in the override, so the running process looks at the copy.

It's also of note that while two WAN interfaces are present and the GUI configures them under the separate interface pages, overrides configurations can only be specific once and must have the configuration for both interfaces.

# /var/db/dhcp6c_duid
/var/db/dhcp6c_duid holds the DUID generated when dhcp6c starts.  This appears to be regenerated each time - unless you specify the DUID in the Opnsense configuration (which is under "Interfaces"->"Settings", not under each interface configuration). 

Since I needed this static, I found lots of references on the internet to saving the DUID file to /conf and having it copied in place - Opnsense seems to created the proper override of DUID since those posts.

> [!NOTE]
> Sidebar.  DHCP6C is part of the the (very old) WIDE-KAME project, which has been decomisissioned.  I did find two branches of code - one that OpenBSD seems to be packaging from an 2008 release and one from Opnsense branched from a 2005 release.   THey. Don't. Work. The. Same.   Also, the one in the Opnsense project seems to be actively maintained.  This is all speculation and inference - have not really researched the ancestry of both builds.  The OpenBSD version will not build easily on FreeBSD / Opnsense due to a conflict with the definition of dprintf with the stystem common.h - it will build if you deal with it, but using it didn't actually fix my Comcast delegaton woes.

