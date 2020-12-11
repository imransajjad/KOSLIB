KOS is a scripting language and overall an amazing mod for Kerbal Space Program.

https://github.com/KSP-KOS/KOS

Some useful KOS modules and scripts  
  
Contents of my Script/:  
  
boot/  
koslib/  
logs/  
helpers/  
param/

The koslib folder can be used on its own and files can be included from it.

Example/my pattern: Copy over the boot, param and term-scipts folders from boot-copy to the Script folder. A ship should have a core tagged flcom and running the flcom.ks boot file. And another core running a *-flcs.ks boot file and tagged flcs. Both these files will load a file param/[PARAM_NAME].json, where PARAM_NAME is a first letter of each world acronym for the ship's name. For example, if ship is named "Docker Tester 2", the param file should be param/dt2.json.
