Build Editions (Bedi) v7.44
===========================
Changelog:
+ New baseline for 22000, 22621, 25398
+ Lite options support for 25398
+ Remove defender now including disable bitlocker and VBS
+ New vaccine packages
+ General tweaks
+ Some fixs and improvements
+ New hints


To update the image:
- Create modding LCU with tool number 9.
  Put the .MSU to the root folder of Bedi (inside Bedi folder), run Bedi, choose 9.
  The result will be in the folder 'update' inside the build number folder.
  If you already have both esd files (ssu and lcu) in the update folder, there is no need to create them again, except got new patch tuesday.
  Put any other update packages (no need to mod) inside the update folder with .cab format (extract from MSU file with 7z usualy).
  Bedi doing modding process on the fly for .cab files and not changing anything the original cab packages.
- Run Bedi, update the image with tool number 10.


Version notes:
--------------
- About 25398 Package needed.
  Please, follow this post instruction.
  https://forums.mydigitallife.net/threads/guide-discussion-windows-editions-reconstructions.88605/page-69#post-1868095
  You can use gailium119's source.esd packages, rename to clients.esd and put it in to 25398 folder.
  Get the FODs and it language by your self.
  If you need MSEDGE, get the file (Wim_Edge.wim) from the below link. Put it in to 25398 folder and rename to Edge.wim
  https://uupdump.net/findfiles.php?id=88e4674c-33b5-4ba6-aef8-8efff653dd93&q=edge
- About language package. 
  If you don't have one, please get it for yourself on uupdump.net according to the build number. You must have one!
  After download rename it according to what is written on uupdump.net and then put them to the build number version.
- When you want to update the image, you no longer need to select the Lite options menu,
  because the settings are integrated with the image.
- Edit upmod.cmd and give commenting for tweaks (line 194, rem call :generaltweaks) if you are not want it.

Good luck.
------------------------------------------------------------------------------------------------------------------

Sample build number folder:
----------------------------
X:\Bedi\22621>
<DIR> fods
<DIR> update
Microsoft-Windows-Client-LanguagePack-Package-amd64-en-us.esd
Microsoft-Windows-EditionSpecific-EnterpriseG-Package.esd
Microsoft-Windows-EditionSpecific-EnterpriseS-Package.esd

Sample update folder:
----------------------
X:\Bedi\22000\update>
defender-dism-x64.cab
microsoft-windows-netfx3-ondemand-package~31bf3856ad364e35~amd64~~.cab
SSU-22000.3250-x64.esd
windows10.0-kb5007575-x64_CU_Netfx35.cab
Windows10.0-KB5011048-x64_NDP481-Base_9110.10.cab
Windows10.0-KB5044280-x64.esd
Windows11.0-KB5044032-x64-NDP481_10.0.9277.2.cab

Sample FODs folder:
-------------------
X:\Bedi\22000\fods>
microsoft-windows-mspaint-fod-package-amd64-en-us.cab
microsoft-windows-mspaint-fod-package-amd64.cab
microsoft-windows-mspaint-fod-package-wow64-en-us.cab
microsoft-windows-mspaint-fod-package-wow64.cab
microsoft-windows-notepad-fod-package-amd64-en-us.cab
Microsoft-Windows-Notepad-FoD-Package-amd64.cab
microsoft-windows-notepad-fod-package-wow64-en-us.cab
microsoft-windows-notepad-fod-package-wow64.cab
microsoft-windows-snippingtool-fod-package-amd64-en-us.cab
microsoft-windows-snippingtool-fod-package-amd64.cab

---------------------------------------------------------------------------------------------------------------------

=====================
Support Build Numbers
=====================

Starter
-------
15063.0

EnterpriseS
-----------
No need any key. Use it when you have one.
17763.1
19041.1 (IoTEnterpriseS)
22000.1 (IoTEnterpriseS) use tool number 10 to update the image
22621.1 (IoTEnterpriseS) use tool number 10 to update the image
25398.1 (IoTEnterpriseS) use tool number 10 to update the image
26100.1 (IoTEnterpriseS)

EnterpriseG
-----------
Use volume (GVLK) key, but actually it doesn't require any key.
17763.1
19041.1
22000.1
22621.1
25398.1
26100.1
27729.1000
...perhaps any new build ones which have Professional with build number .1 or .1000 (without any update package inside) image and
   specific enterpriseG package and language package.

WNC
---
All credits to @gailium119 at https://forums.mydigitallife.net/threads/guide-discussion-windows-editions-reconstructions.88605/page-41#post-1861917
Use Retail key
26100.1
- Microsoft-Windows-EditionPack-WNC-Package.ESD
- Microsoft-Windows-EditionPack-WNC-WOW64-Package.ESD
Get the two packages above from, https://uupdump.net/get.php?id=cd4dec48-2f0f-4038-9f99-19dceeeecff0&pack=en-us&edition=wnc
Put them to the 26100 folder

Limitation:
-----------
- All using Professional image (instal.wim) except the Starter using Core (home) image.
- Server to (IoT)EnterpriseS/G use server datacenter core image.
- All image in en-US, x64 (amd64) and without any update packages inside.

Howto:
------
- Extract Bedi archieve to the root drive (example, c:\ or d:\ or e:\ ...and go on)
- Put install.wim to the 'root folder' (inside Bedi folder). Run Bedi.cmd as Administrator.

Note:
-----
If you want to try create IP (new one), create the folder with the build number,
put all the necessary files in there (specific and language package).

In this root folder, don't save any files in/or create folders with mnt*, lcu*, lp* log*, sdir*, and sxs* names.
This script will cleanup them automatically.

Some files are needed if they don't already exist and have to be found by yourself;
- LanguagePack, Microsoft-Windows-Client-LanguagePack-Package-amd64-en-us.esd
- EnterpriseS, Microsoft-Windows-EditionSpecific-EnterpriseS-Package.esd
- EnterpriseG, Microsoft-Windows-EditionSpecific-EnterpriseG-Package.esd
Create a folder with name like the build number, put them all in.


========
Credits:
--------

Creator:
--------
@javac75
https://forums.mydigitallife.net/members/javac75.485029/
https://forums.mydigitallife.net/threads/guide-discussion-windows-editions-reconstructions.88605/page-41#post-1861506


Concept/Inspiration:
--------------------
abbodi1406
https://forums.mydigitallife.net/threads/abbodi1406s-batch-scripts-repo.74197/

@AveYo
https://forums.mydigitallife.net/threads/lean-and-mean-snippets-for-power-users-runasti-reg_own-toggledefender-edge-removal-redirect.83479/

@xinso
https://forums.mydigitallife.net/threads/guide-discussion-windows-editions-reconstructions.88605/page-47#post-1862786

@gailium119
https://forums.mydigitallife.net/threads/guide-discussion-windows-editions-reconstructions.88605/page-41#post-1861917

PSFExtractor:
BetaWorld
https://github.com/Secant1006/PSFExtractor

NSudo:
@Mouri_Naruto
https://forums.mydigitallife.net/threads/nsudo-series-of-system-administration-tools-general-thread.59268/

WinSxS Suppressors:
https://github.com/asdcorp/haveSxS

And The members at MDL and stackoverflow.com

---------------------------------------------------------------------------------------------------------------

============
Old version:
------------
Bedi v7.31
==========
Changelog:
+ New menu (5,6) only for 25398
+ 25398 (IoT)EnterpriseS, use 26100 license.
+ 25398 EnterpriseG, use 26100 license.
+ 25398 Modding and update (Tools option).
+ New Cleanup menu.
+ New hints
+ Turn back to use Microsoft-Windows-Common-RegulatedPackages-Package for EnterpriseS.

Bedi v6.31
==========
Changelog:
+ Add some lite options. (Exclusive only for image with build number 22000.1 and 22621.1
  It's permanently remover because upmod.cmd will keep it like that if you update with that tool.
+ Change and add update image tools (upmod.cmd)
+ Some vaccine packages
+ Update ModLCU.cmd and upmod.cmd
+ Several fixs to improve script performance
- Remove language packages, so it reduce Bedi sizes. But you must have it in each build number folder.

Bedi v6.10
==========
Changelog:
+ Add InternetBrowser package to "\Bedi\22000\Microsoft-Windows-EditionSpecific-EnterpriseS-Package.esd"
+ Add Modding Last Cumulative Update (LCU) script to support updates for EnterpriseS 22000 and 22621 official leaked only
  Thanks to @Xinso who has enlightened all of us. (https://forums.mydigitallife.net/threads/guide-discussion-windows-editions-reconstructions.88605/page-47#post-1862786)
  To create EnterpriseS LCU for 22000 or 22621:
  ~ Put the last LCU.msu file to the root folder (ex. LCU for 22621; windows11.0-kb5046633-x64_LCU_4460.1.11.msu)
  ~ Run BuildEdi.cmd as administrators, choose 9. Enter.
    Output files will be exist in build number folder (ex. Bedi\22621\SSU-22621.4383-x64.esd and Bedi\22621\Windows11.0-KB5046633-x64.esd)
	If that two files allready exist, you can remove/delete the msu file.
  ~ Use dism to update them all. (ex. Dism.exe /image:mount /add-package:"22621\SSU-22621.4383-x64.esd")
    You can update other package like NPD48/1, put the NDP48/1 packages in to the build number folder.
	(ex. Dism.exe /image:mount /add-package:22621\Windows11.0-KB5045935-x64-NDP481.cab)
	In the files folder, there are sample script to doing this all (upmod.cmd). Put the script to the root folder.
  ~ When you finish it, don't forget to run cleanup.cmd
  ~ You must create EnterpriseS image from the scrath with Bedi if you want to get the lastest update. I'm sorry for that.
    Otherwise, you can try it.
+ Several fixs to improve script performance
+ Rename readme.txt to Bedi_Readme.txt

Good Luck.
