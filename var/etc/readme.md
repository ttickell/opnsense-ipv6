# Background
## /var/etc/dhcp6c.conf.custom
/var/etc/dhcp6c.conf seems to be what is used by Opnsense when it starts dhcp6c.  While there's an option to override with a custom configuration, in practice it looks /var/etc/dhcp6c.conf is overwritten by by the file specific in the override, so the running process looks at the copy.

It's also of note that while two WAN interfaces are present and the GUI configures them under the separate interface pages, overrides configurations can only be specific once and must have the configuration for both interfaces.

## /var/db/dhcp6c_duid
/var/db/dhcp6c_duid holds the DUID generated when dhcp6c starts.  This appears to be regenerated each time - unless you specify the DUID in the Opnsense configuration (which is under "Interfaces"->"Settings", not under each interface configuration). 

Since I needed this static, I found lots of references on the internet to saving the DUID file to /conf and having it copied in place - Opnsense seems to created the proper override of DUID since those posts.

> [!NOTE]
> Sidebar.  DHCP6C is part of the (very old) WIDE-KAME project, which has been decommissioned.  I did find two branches of code - one that OpenBSD seems to be packaging from an 2008 release and one from Opnsense branched from a 2005 release.   They. Don't. Work. The. Same.   Also, the one in the Opnsense project seems to be actively maintained.  This is all speculation and inference - have not really researched the ancestry of both builds.  The OpenBSD version will not build easily on FreeBSD / Opnsense due to a conflict with the definition of dprintf with the system common.h - it will build ifyou deal with it, but using it didn't actually fix my Comcast delegation woes.

# This Configiuration
This configuration is semi-self-explanatory once you've beaten your head against dhcp6c for a few frustrating days.

> [!NOTE]
> The odering may or may not be important to you.  I had to have Comcast, first, to make sure it saw the DUID I stole from another system.  The other thing I learned is that AT&T will keep re-issuing the same eight /64s - but it will if the DUIDs change, the order of issuance changes.  This creates a giant pain in the butt if your whole network has been using one delegation, you change the order of the configuraiton, and suddenly your network has a closely related but entirely different /64.  Close doesn't count in prefix delegation and IP routing ... It does eventually fix itself if SLAAC is being used - but all bets are off if you think you ahve a bunch of IPv6 addresses defined to be issued via DHCP6. 
>
> Yes, I shot myself in the foot.  Go ahead, mock me. 
>
> That acutally lead me to https://blogs.infoblox.com/ipv6-coe/3-ways-to-ruin-your-future-network-with-ipv6-unique-local/ - and even after getting this all working, it might make more sense to use NPTv6 on everything.

This file, in sections reads (and annotated, here):

```
## Comcast
interface igc1 {                            # On this network interface
  send rapid-commit;                        # I actualy don't get this one - maybe required?
  send ia-na 0;                             # Get an address under id '0' for that interface

  send ia-pd 0;                             # Request a prefix (see below for prefix size, not here!?)
  send ia-pd 1;                             # Request another one, because we can
  
  script "/var/etc/dhcp6c_wan_secondary.sh";# Run this script on changes (null script for data, here)
  request domain-name-servers;              # ask for name server (I ignore them and use DNS over HTTP)
  request domain-name;                      # ask for domain name (I ignore that too)
};
```
Pretty straight forward except where it's not.  The ia-pd and ia-na numeric ids are referencable and unqiue.  They will be used to further define both what the request should be and what we do with it.

Next up, associate the ia-na 0 (the address we requested for the interface):

```
id-assoc na 0 { };
```

Yes, this is an empty block.  dhcp6c will bomb if you don't define it, I can't find anyone that does anything with it, but every ia-na or ia-pd needs to be asoociated in an id-assoc block.  They guys actually maintaining dhcp6c can proably tell me why this is and I would probably owe them a beer (possibly to help dull their pain of having to use smaall words for me).

Now, we see something a litte more useful:

```
id-assoc pd 0 { 
  prefix ::/60 21600 86400;
};

id-assoc pd 1 { 
  prefix ::/60 21600 86400;
};
```
The ia-pd (prefix delegation) needs to be associate, too, but in this context we're only associating it with a definition of what we want the request to be.  Comcast will issue a /64 unless asked nicely for a /60.   Since we are asking nicely, twice, we get two - but we aren't doing anything with them in this configuration (I'll need them for NPTv6 configuration).

> [!NOTE]
> This is a /60 - or 16 x /64s or whatever subnet madness you want.  If we were splitting this up, we'd assign the prefix delegations to specifci interfaces _inside_ the id-assoc block for tha prefix.  Below you will see this for the AT&T, but since we get 8 unique /64 PDs, those will only assign one interface inside each block.  I'll add an example of spliting a PD at the end.

Ok, on to AT&T.   The start is similar - but I do it six times to get six unique /64s, as AT&T won't honor anything larger.  AT&T will provide eight - but I use two on a different system to play with IPv6 only networks.

```
## AT&T
interface igc0 {
  send rapid-commit;
  send ia-na 1;                            # request stateful address

  send ia-pd 2;                            # request prefix delegation
  send ia-pd 3;                            # request prefix delegation
  send ia-pd 4;                            # request prefix delegation
  send ia-pd 5;                            # request prefix delegation
  send ia-pd 6;                            # request prefix delegation
  send ia-pd 7;                            # I remember scratched CDs
  request domain-name-servers;
  request domain-name;
  script "/var/etc/dhcp6c_wan_script.sh";  # Opnsenes stock "do some stuff" script
};
```

Like above, and empty block for the id-na association - note this is id-na _1_ not _0_:
```
id-assoc na 1 { };
```

Now we tie the ia-pd to things. In this case, we don't specify a prefix but we do specify which interface gets what:

```
## LAN Interface
id-assoc pd 2 {                          # associate this PD
  prefix-interface igc2 {                # to this interface
    sla-id 0;                            # this segment of the PD
    sla-len 0;                           # with this segment length
  };
};

id-assoc pd 3 { 
  prefix-interface igc3 {
    sla-id 0;
    sla-len 0;
  };
};
```

The interesting bits are a) it hooks up to the inteface (i.e. igc2) _and_ it's the first (0) network segment of one of length 0 (/64, since that's what I got).  With this, dhcp6c will assing the interface an address in the range specified.

The process is repeated for PD 3.  Finally:

```
id-assoc pd 4 { };
id-assoc pd 5 { };
id-assoc pd 6 { };
id-assoc pd 7 { };
```

Empty id-assoc blocks to we don't break dhcp6c head by asking for something we're not using (even if we use it statically, elsewhere). 

That's it, that's the whole file that works for Comcast and AT&T - with the noted caveats.  

If I was using Comcast as a primary, and still wanted /64s on both igc2 and igc3, the block would look like this:

```
id-assoc pd 0 { 
  prefix ::/60 21600 86400;
  prefix-interface igc2 {
    sla-id 0;
    sla-len 4;
  };
  prefix-interface igc3 {
    sla-id 0;
    sla-len 4;
  };
};
id-assoc pd 1 {
  prefix ::/60 21600 86400;
};
```

This is more interesting from seeing how the associations work.  We ahve a /60 (16 /64) - and we are assigning two of them.  basically take the first block of space, mask it with an additional 4 bits (60+4) for a /64, and asign that block to that inerface. 

The second interface gets the next block that matches that 60+4 length.  If we were breaking it into /61s and delegating them to interfaces that would further delegate them, we'd have sla-id 0/sla-len 1 and sla-id 1/sla-len 1.

This seems to make lots of sense, now, but I'll admit it took me reading the man page for dhcp6c.conf and a bunch of internet links to actually get why it was this way.  Getting to where the ia-pd is an object with an ID in my head took some time ...

