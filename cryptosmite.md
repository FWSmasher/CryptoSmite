# CryptoSmite

# **<u>We are not responsible for any problems or issues that occur on your chromebook. We are also not responsible for any trouble you face at your school or organization</u>**
## Files to download
Download [stateful.tar.xz](https://drive.google.com/file/d/19-NPB9Mukn6JdHZ7FUUn4QwEKMMh85C1/view?usp=sharing) and [st.tar.xz](https://drive.google.com/file/d/1YlgNDslOIrOAQJuQ-AoL0FuE7Xve71Co/view?usp=sharing)  
or just simply get them both [here](https://fwbasher.netlify.app/) (not affliated)
I promise it will be in a better storage medium soon but right now its in google drive.  
## **GOOGLE CANNOT PATCH THIS EXPLOIT**  
TO RECEIVE THE **FULL** PATCH ***YOU NEED TO BUY A NEW CHROMEBOOK***

## Instructions
(TODO: Automate these instructions)
### Setup
1. Build a [sh1mmer](https://osu.bio/builder) shim. (Step no longer necessary thanks kxtz, instead download a raw shim)
2. Run cryptosmite_host.sh on the shim using the files specified above. Rename st.tar.xz to cryptsetup.tar.xz and follow the usage instructions in host. This should work if you have a sh1mmered shim, or a raw shim.
### Main instructions
1. Boot into shim (Plug in your raw shim, and press esc+refresh+power, ctrl-d, enter, esc+refresh+power again, plug in shim, it should boot).
2. Run cryptosmite.sh in the tui shim
3. Run cryptosmite.sh in shim
5. Exit the shell to unmount
6. The system will boot to oobe. Press continue, select a wifi network, reach the "Choose the account to login" page, and then reboot and enable devmode.
7. After that you can unenroll through the following commands:
```
vpd -i RW_VPD -s check_enrollment=0
cryptohome --action=remove_firmware_management_parameters
```
Run these commands immediately when you start up. Otherwise the stateful will be configured to always re-enroll and you will need to powerwash.  
To make unenrollment quicker, you can skip the devmode transition (the 5-minute wait).
Skip_devmode_transition.sh
```bash
mkfs.ext4 -F /dev/{your target bootdisk}p1
mount -o loop,rw /dev/{your target bootdisk}p1 mnt
touch mnt/.developer_mode
umount mnt
reboot
```
8. You should be fully unenrolled
### Re-enrollment instructions
1. If your school has auto re-enrollment enabled, you can proceed by powerwashing and re-enrolling.
2. If you are unfortunate and don't have auto re-enrollment enabled you will need to capture a token that will be used to re-enroll later
3. On the first attempt, re-enroll and then run cryptosmite.sh on the shim with a parameter, this should extract stateful in its current state. (I also recommend doing these steps if you have auto-enrollment. Your admin might disable this in the future)
4. Save it to your pc, and don't lose it. You will need it later to re-enroll again. Enable devmode and verified and then back to devmode. You might face a filesystem issue when booting up and waste extra time. This should clear out the filesystem, and then run the exploit again.
5. Run this through the enrollment toolkit (work in progress) (which will make it work by swapping out unenrollment stateful with enrollment stateful)
7. Now you can re-enroll by using this stateful

### Features of the work in progress re-enrollment toolkit
1. You get enable the lacros96 dlc, which will allow you to use an unblocked browser when you are logged in with your school account. Even if that dlc gets updated, you still get the unblocked profile.
2. You can setup crostini on the same school account.
3. Yea we are planning to add more stuff stay tuned
