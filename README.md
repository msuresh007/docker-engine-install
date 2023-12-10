# docker-engine-install
### Introduction
This script facilitates the installation of Docker Engine on Windows computers without the necessity of Docker Desktop. Docker Desktop often requires licensing for commercial use-cases (Ref: https://www.docker.com/pricing/).

### Reason for this script
-  Despite numerous articles available on Docker Engine installation, I noticed a lack of a comprehensive guide consolidating all necessary steps. Most write-ups assume Administrator access, yet in a corporate setup, users commonly operate with Standard User access, restricting installations to the Administrator level. Therefore, it's crucial to outline steps enabling Standard Users' access to Docker Engine, motivating the creation of this script.
-  One-Click Installation - Although several articles attempt to outline steps, I haven't encountered a single script covering all the essential actions. I aimed to simplify life by creating a script for easy one-click installation.

### Pre-requisites

 1. PowerShell Core - https://github.com/PowerShell/PowerShell 
 1. Administrator User access is required for executing this script.

### How to run the Script
1. Download the InstallDockerEngineAndDependencies.ps1 file.
1. Edit the variables $downloadPath, $dockerInstallPath, and $accountName to reflect your specific requirements.
1. During each step's execution, the system may prompt for a computer restart as needed. You can choose to restart immediately or postpone until after the script execution completes.
1. If multiple standard users on your computer require access to Docker, you can add them to the newly created user group "DockerUsers," enabling them to use Docker seamlessly.
1. Once all steps are completed, verify the Docker setup by executing docker run hello-world.

### Feedback   
You are most welcome to provide any feedback to improve this script. Please feel free to reach out on email or LinkedIn.
 
 ### Legal Stuff
This script reflects what I found effective for my use. However, it doesn't guarantee similar results for you. Any damages incurred upon its usage are solely your responsibility. Understand the steps thoroughly and execute them cautiously.

All the best!

**Suresh Madadha**   
Email: msuresh007@gmail.com   
LinkedIn: https://www.linkedin.com/in/suresh-madadha/   
 
