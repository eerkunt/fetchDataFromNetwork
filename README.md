# fetchDataFromNetwork

This script uses ```Net::Telnet``` to initiate discovery on given list of IPs. It runs multi-threaded.

It also checks for some propriety stuff ( like VLAN103 is really there ), but also collects some system information and neighbourhood data. 

Based on the data collected from the network, script generated a network map ( in HTML format ) showing uptimes ( based on colors ) to identify possible problems if your monitoring/alarm systems are not clever enough.

I will also try to add a sample output HTML file later.
