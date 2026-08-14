# AI HAT+ Software Setup
## Introduction
This guide covers the software setup required to use the Raspberry >

## Phase 1: ROS 2 Jazzy Base Install on Raspberry Pi 5

This is phase one of a benchmarking project on the Raspberry Pi 5 w>

####  Goal of this phase

Get `ros-jazzy-ros-base` installed and confirmed working on a fresh>

### Step 1: Update the system


```bash

sudo apt update
sudo apt upgrade
```

`apt update` refreshes the local list of what packages are availabl>

`apt upgrade` installs newer versions of packages you already have,>

### Step 2: Try installing ROS 2 base
```bash
sudo apt install ros-jazzy-ros-base
```


#### The error


** E: Unable to locate package ros-jazzy-ros-base **



This means apt has no idea what this package is, because the ROS 2 >

### Step 3: Confirm the Ubuntu version
```bash
lsb_release -a
```


This prints the Ubuntu version and codename (for example Noble for >

### Step 4: Check what ROS packages apt can currently see
```bash
apt search ros-jazzy
```


If this comes back empty, it confirms the ROS repository is missing>

### Step 5: Add the ROS 2 repository

Run each line separately:

```bash
sudo apt update



sudo apt install -y software-properties-common curl
sudo add-apt-repository universe



sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/mast>

  -o /usr/share/keyrings/ros-archive-keyring.gpg



echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/k>



sudo apt update
```




What each part does:

-**software-properties-common** and **curl** are tools needed to ma>

-**add-apt-repository universe** turns on Ubuntu's "universe" repos>

-The **curl** command downloads ROS's signing key and saves it to *>

-The **echo ... | tee**  line writes a new file telling apt where t>

The final **apt update** re-reads all repositories, now including t>
### Step 6: Confirm the repo works
```bash
apt search ros-jazzy
```


If a long list of packages comes back, the repository is working an>

### Step 7: Install ROS 2 base
```bash
sudo apt install ros-jazzy-ros-base
```


#### Verifying the install

- **Is the package actually installed?**
```bash
dpkg -l | grep ros-jazzy
```


`dpkg -l` lists every installed package on the system. Piping it th>

- **Does the ROS folder exist?**
```bash
ls /opt/ros/jazzy
```


ROS 2 installs itself into `/opt/ros/jazzy`. Seeing folders like **>

- **Can you load ROS into your shell?**

```bash
source /opt/ros/jazzy/setup.bash

ros2 --version
```


Installing ROS does not automatically make its commands available i>

-Can ROS see its own packages?
```bash
source /opt/ros/jazzy/setup.bash



ros2 pkg list | head
```


This asks ROS to list every package it knows about, then **head** s>

**Phase 1 result**

ROS 2 Jazzy base is installed, sourced, and verified working on a f>







## Phase 2: Getting the Hailo Packages onto the Pi


### Step 1: Get access to the Hailo Developer Zone

Go to the Hailo software downloads page:

https://hailo.ai/developer-zone/software-downloads/?product=ai_acce>



Figure 2.1.1: The Hailo Developer Zone



You need a free Hailo account to see the download links. Sign up, l>





Figure 2.1.2: Selecting as per your device



Figure 2.1.3: Setting the parameters





Figure 2.1.4: Downloading the right packages




Figure 2.1.5: Finding the needed packages





Figure 2.1.6: Downloading Tappas Python Binding

Step 2: Know what you're downloading



Figure 2.2.1: Packages required



The Hailo software stack is made up of five packages:

- **HailoRT PCIe Driver** (.deb) - the kernel driver that lets the >

- **HailoRT** (.deb) - the runtime itself. Loads compiled models on>

- **HailoRT Python Binding** (.whl) - lets Python scripts call into>

- **TAPPAS Core** (.deb) - Hailo's GStreamer pipeline framework, us>

- **TAPPAS Core Python Binding** (.whl) - the Python side of TAPPAS>

For pure benchmarking, only the first three matter. The benchmark s>

### Step 3: Move the packages from your PC to the Pi

The Hailo packages are downloaded on your PC, because the Hailo web>

Use **scp (Secure Copy**) to transfer them over SSH.

Example:

scp ~/Downloads/hailort_<version>_arm64.deb smartai@smartai.local:~>

Meaning:

- scp → securely copies files between computers.

- ~/Downloads/...deb → file on your PC (source).

- smartai@smartai.local → Raspberry Pi (username + hostname).

- :~/hailo_packages/ → destination folder on the Pi.

- It uses the same SSH authentication as ssh smartai@smartai.local.

If you have multiple packages, you can copy them individually, or c>

scp -r ~/Downloads/hailo_stack/ smartai@smartai.local:~/hailo_packa>

Figure 2.3.1: Copying packages to Pi



### Step 4: Confirm the files landed

On the Pi:
```bash
ls ~/hailo_packages/
```
You should see the **.deb** and **.whl** files listed. 

## Phase 3: Installing the Driver, Runtime, and Python Bindings

The five Hailo packages split into two different installation metho>

#### .deb vs .whl, and why they're handled differently

A **.deb** file is a Debian package. It's installed with apt or dpk>

A **.whl** file is a Python wheel. It's installed with pip, and it >

The reason the .whl needs more care is that ROS 2 and other tools m>

### Step 1: Install the PCIe driver (.deb)
```bash
cd ~/aihat+

sudo apt install ./hailort-pcie-driver_4.24.0_all.deb

```

This one failed the first time with:

E: Sub-process /usr/bin/dpkg returned an error code (1)


The PCIe driver isn't just a file copy, it builds a kernel module a>

### Step 2: Install the HailoRT runtime (.deb)
```bash
sudo apt install ./hailort_4.24.0_arm64.deb
```

This one went through cleanly. Unlike the driver, HailoRT is a preb>

### Step 3: Find and install the correct kernel headers
```bash
dpkg -l | grep linux-headers
```

This showed generic headers installed (linux-headers-6.8.0-137), bu>

```bash
apt search linux-headers-6.8.0-1060-raspi
```

This confirmed the correct headers package existed in the repos, so>

```bash
sudo apt install linux-headers-6.8.0-1060-raspi

```
To confirm the fix landed correctly:

```bash
ls -l /lib/modules/$(uname -r)/build
```

**$(uname -r)** fills in the exact running kernel version, so this >

### Step 4: Reconfigure the driver and reboot
```bash
sudo dpkg --configure hailort-pcie-driver

sudo reboot

dpkg --configure re-runs the setup steps for a package that's alrea>
```

### Step 5: Confirm the driver is detected
```bash
lsmod | grep hailo

ls /dev/hailo*

hailortcli fw-control identify
```


Figure 3.5.1: Confirm driver is being detected

**lsmod** lists currently loaded kernel modules, grep hailo filters>

**hailortcli fw-control identify** goes one step further and actual>

### Step 6: Install the Python binding (.whl)
```bash
python3 -m venv ~/my_hailo_venv

source ~/my_hailo_venv/bin/activate

Pip install  - -upgrade pip

pip install hailort-4.24.0-cp312-cp312-linux_aarch64.whl
```

A virtual environment (venv) is a self contained Python install, se>

The first install attempt failed with a bad wheel error. Wheel file>

`pip install hailort-4.24.0-cp312-cp312-linux_aarch64.whl`



Figure 3.6.1: Confirm the versions of packages 



### Step 7: Install the Hailo apps and run the post install step

In the same virtual environment:
```bash
pip install -e

hailo-post-install
```

Installing hailo-apps via pip install -e in the same venv keeps eve>



**N/B:** The first run of hailo-post-install failed here with:

PermissionError: [Errno 13] Permission denied: '/usr/local/hailo'

The script needs to create files under /usr/local/hailo, which sits>

```bash
sudo mkdir -p /usr/local/hailo/resources/packages

sudo chown -R $USER:$USER /usr/local/hailo

hailo-post-install
```




Figure 3.7.1: Re-running hailo-post-install







