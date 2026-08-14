# Introduction

The Raspberry Pi AI HAT+ is an official Raspberry Pi add-on board designed to provide hardware-accelerated Artificial Intelligence (AI) inference on the Raspberry Pi 5. It contains a Hailo Neural Processing Unit (NPU) that executes supported AI models directly on dedicated AI hardware instead of relying solely on the Raspberry Pi CPU.

By offloading AI workloads to the Hailo NPU, the AI HAT+ offers:

Faster AI inference

Lower CPU utilization

Reduced power consumption

Lower latency for real-time applications

Improved privacy through local (edge) AI processing

The Raspberry Pi AI HAT+ integrates seamlessly with Raspberry Pi camera frameworks such as rpicam-apps and Picamera2, allowing supported AI tasks including image recognition and object detection to run on the onboard Hailo accelerator. While Raspberry Pi OS automatically detects the hardware, users must still install the required software packages and compatible AI models before hardware-accelerated inference can be performed.



## AI HAT+ vs AI HAT+ 2

|Feature |AI HAT+ |AI HAT+ 2
|--------|--------|------------
Accelerator Chip|Hailo-8L (13 TOPS) or Hailo-8 (26 TOPS)|Hailo-10H (40 TOPS)

Memory|Uses Raspberry Pi 5 system memory|Dedicated 8 GB onboard memory

LLM Support|Not supported|Supported

VLM Support|Not supported|Supported

Typical Applications|Object detection, robotics, computer vision, camera AI|All AI HAT+ applications plus local LLMs and Vision-Language Models


The AI HAT+ is primarily intended for computer vision and robotics applications, while the AI HAT+ 2 extends these capabilities by supporting compact Large Language Models (LLMs) and Vision-Language Models (VLMs).



## Prerequisites

Before installing the AI HAT+, ensure that the following hardware has already been assembled:

Raspberry Pi 5

Raspberry Pi 5 Active Cooler (heatsink and fan) or another compatible cooling solution

Raspberry Pi official case (optional)

Raspberry Pi AI HAT+

AI HAT+ accessory kit (standoffs, screws, spacers and GPIO header)

Important: Completely power off the Raspberry Pi and disconnect the power supply before installing the AI HAT+.



#HARDWARE INSTALLATION

##Step 1: Unbox the Raspberry Pi AI HAT+



Figure 1a: AI HAT+ package

Figure 1b: AI HAT+ package features



After opening the package, verify that all accessories are present.

The package typically contains:

Raspberry Pi AI HAT+

PCIe ribbon cable -4

Long mounting screws - 2

Short mounting screws

Metal standoffs/spacers - 1

40-pin GPIO header - 3





Figure 1c: AI HAT+ package contents.



##Step 2: Inspect the AI HAT+

Before installation, identify the major components of the board.

You should be able to observe:

The Hailo Neural Processing Unit (NPU)

The 40-pin GPIO connector

The PCIe ribbon cable connector

Mounting holes for the standoffs

The PCIe ribbon cable is delicate and should be handled carefully. Avoid excessive bending, twisting, or pulling during installation.



Figure 2: AI HAT+ board showing major components.

##Step 3: Identify the Mounting Hardware

The installation kit contains two different screw lengths.

Long screws are used for the lower mounting points and pass through the Raspberry Pi before connecting to the spacers.

Short screws are used to secure the AI HAT+ onto the spacers after the board has been positioned.

Separating the screws before beginning the installation makes the assembly process easier.



 Figure 3: Long and short screws, spacers, and GPIO header.

##Step 4: Install the GPIO Header

Insert the supplied 40-pin male GPIO header into the AI HAT+.

Installing the GPIO header before connecting the PCIe ribbon cable provides better access and makes the installation easier.

Ensure the header is fully inserted and aligned correctly.



Figure 4: Installing the GPIO header.

##Step 5: Connect the PCIe Ribbon Cable

Carefully connect the PCIe ribbon cable between the Raspberry Pi 5 PCIe connector and the connector on the AI HAT+.

Take extra care because:

The ribbon cable is delicate.

The connectors should close securely.

The cable should remain straight without excessive twisting.

The cable should align naturally with both connectors.

Improper insertion or excessive force may damage the connector or prevent the AI accelerator from being detected.



Figure 5: Connecting the PCIe ribbon cable.

##Step 6: Mount the AI HAT+

Position the AI HAT+ directly above the Raspberry Pi.

Carefully align:

The GPIO header

The mounting holes

The PCIe ribbon cable

Lower the board slowly onto the GPIO pins.

Important: Do not force the board into position. Misaligned GPIO pins can bend easily, resulting in poor electrical contact or permanent damage.



 Figure 6: Positioning the AI HAT+.

##Step 7: Secure the AI HAT+

Using the short screws, fasten the AI HAT+ to the metal standoffs.

Tighten each screw gradually until the board is firmly secured.

Do not overtighten the screws, as this may damage the PCB.

Once secured, verify that:

The board is level.

The GPIO header is fully seated.

The PCIe ribbon cable remains securely connected.

No pins are bent.



###Hardware Installation Complete 

Congratulations! The Raspberry Pi AI HAT+ hardware installation is now complete.

The next stage involves installing the required Hailo software packages and AI models so that Raspberry Pi OS can utilize the onboard Neural Processing Unit for hardware-accelerated AI inference.

Troubleshooting Tips

If the AI HAT+ is not detected during software installation, first inspect the hardware before troubleshooting the software.

Check the following:

Ensure the PCIe ribbon cable is fully inserted at both ends.

Confirm that the ribbon cable is oriented correctly.

Verify that the GPIO header is properly aligned.

Inspect the GPIO pins for any bends or misalignment.

Confirm that all mounting screws are secure without stressing the board.

Ensure the Raspberry Pi was powered off during installation.

Many hardware detection issues are caused by loose or improperly aligned connections rather than software configuration.


####Documentation

For additional information, detailed images, and a more visual walkthrough of the Raspberry Pi AI HAT+ hardware setup, visit the accompanying blog post on Substack:

[Read the full documentation and setup guide](https://roboticsdojo.substack.com/p/8a034d5a-fea6-44fb-bcb7-1f7550ee774d?postPreview=free&updated=2026-07-10T11%3A41%3A09.109Z&audience=everyone&free_preview=false&freemail=true)
