# CryptoSmite
New unenrollment exploit that uses stateful files to unenroll.
## How does it work?
We use stateful "backups" that basically allows us to change the encrypted contents of the stateful partition, to arbritary contents. This data is useful for enrollment status, so we changed it to make the device appear unenrolled. On the OOBE, it starts the AutoEnrollmentController, which chains into the ash ownership system, and then the ownership system checks for a file. If this file exists, it removes FWMP. 

## Usage instructions
To use this, you need to look at the instructons [here](https://docs.google.com/presentation/d/1MciRMbDEb3RJomH2gYW9C5qRVjS4P92o2s4QepoCSgY/edit#slide=id.p).

## Any further questions?
Please dm @unretained or join the [support server](https://discord.gg/vF4c99YhNQ) on discord.

### WE AREN'T LIABLE NOR RESPONSIBLE FOR ANY DAMAGE/ISSUES CAUSED BY THIS EXPLOIT! DO NOT CONTACT US FOR ANY ISSUES CAUSED BY THIS EXPLOIT!
### FOR THE TECHNOGICALLY CHALLENGED: IF YOUR DEVICE IS BROKEN OR IF YOU GET IN TROUBLE NOT OUR FAULT AND DON'T CONTACT US ABOUT IT
