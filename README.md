# DockerTask
Use of NSTask with Docker to run Swift code on Linux from Xcode

I use this with XcodeLinuxBridge. 

I create an aggregate build target in Xcode
The target will execute the XcodeLinuxBridge
XcodeLinuxBridge internally uses this DockerTask to fire up Docker and mount a volume
In docker it builds and tests
Finally, it archives the product in the volume so that it is available in the Mac OS to post to S3 or where ever.