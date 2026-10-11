**Confidential** 

**Nikon Corporation** 

# Digital Camera Z 6_2 USB Still Image Capture Device Media Transfer Protocol (MTP) Specifications 

Rev. 1.10 

Nikon Corporation Imaging Division Development Management Department 

Do Not Copy 

1/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## Table of Contents 

|Table of Contents|Table of Contents|
|---|---|
|Table of Contents..................................................................................................................................................................................... 2||
|1|Introduction........................................................................................................................................................................................ 6|
||1.1<br>Application................................................................................................................................................................................ 6|
|2|Outline.................................................................................................................................................................................................. 7|
||2.1<br>PC Connection Mode.......................................................................................................................................................... 7|
||2.2<br>PC Connection Mode and Camera Operations.................................................................................................... 7|
||2.3<br>PC Camera Mode and Remote Mode........................................................................................................................ 7|
||2.4<br>Application Mode................................................................................................................................................................... 7|
||2.5<br>Recording Destination........................................................................................................................................................ 8|
||2.5.1<br>Access to the Card..................................................................................................................................................... 9|
||2.5.2<br>Access to the SDRAM.............................................................................................................................................. 9|
||2.6<br>Sending the Event.............................................................................................................................................................. 10|
||2.7<br>Shooting Operation and Image Data Acquisition in the PC Connection Mode................................... 11|
||2.7.1<br>Command Sequence (Recording in the Card)........................................................................................... 11|
||2.7.2<br>Command Sequence (Recording in the SDRAM).................................................................................... 11|
||2.7.3<br>Command Sequence (Recording by the Shutter-Release Button of the Camera)................. 12|
||2.7.4<br>Command Sequence (Bulb Shooting)............................................................................................................ 12|
||2.8<br>Live View Image and Data Acquisition in the PC Connection Mode........................................................ 13|
||2.8.1<br>Command Sequence.............................................................................................................................................. 13|
||2.8.2<br>Command Sequence (Movie Recording)..................................................................................................... 14|
||2.8.3<br>Command Sequence (Over 4GB Movie Transfer)................................................................................... 14|
||2.8.4<br>Command Sequence (Spot WB)....................................................................................................................... 15|
||2.8.5<br>Command Sequence (Tracking)....................................................................................................................... 17|
||2.9<br>Reacquisition of the Image Data................................................................................................................................. 18|
||2.10 Operation with the Empty Battery............................................................................................................................... 18|
|3|Device Requests........................................................................................................................................................................... 19|
||3.1<br>Standard Device Requests............................................................................................................................................ 19|
||3.2<br>Class-Specific Requests................................................................................................................................................. 20|
||3.2.1<br>Cancel Request.......................................................................................................................................................... 20|
||3.2.2<br>DeviceReset Request............................................................................................................................................. 20|
||3.2.3<br>GetDeviceStatus Request.................................................................................................................................... 20|
|4|Descriptors....................................................................................................................................................................................... 21|
||4.1<br>Standard Descriptors........................................................................................................................................................ 21|
||4.1.1<br>Device Descriptor...................................................................................................................................................... 21|
||4.1.2<br>Device_Qualifier Descriptor................................................................................................................................. 23|
||4.1.3<br>Configuration Descriptor........................................................................................................................................ 24|
||4.1.4<br>Other_Speed_Configuration Descriptor........................................................................................................ 24|
||4.1.5<br>Interface Descriptor.................................................................................................................................................. 25|
||4.1.6<br>Endpoint Descriptor................................................................................................................................................. 26|
||4.1.7<br>Super Speed Endpoint Companion Descriptor......................................................................................... 29|
||4.1.8<br>String Descriptor........................................................................................................................................................ 30|
||4.1.9<br>BOS Descriptor.......................................................................................................................................................... 31|
||4.1.10<br>USB 2.0 Extension Descriptor............................................................................................................................ 31|
||4.1.11<br>Super Speed Device Capabilities Descriptor.............................................................................................. 31|



Do Not Copy 

2/484 

**Confidential** 

## **Confidential** 

## **Nikon Corporation** 

||**Nikon Corporation**|**Nikon Corporation**|
|---|---|---|
||4.2<br>Class-Specific Descriptor................................................................................................................................................ 32||
|5|Protocol|.............................................................................................................................................................................................. 33|
||5.1<br>Generic Container Structure......................................................................................................................................... 34||
||5.2<br>Asynchronous Event Interrupt Data Format......................................................................................................... 34||
||5.3<br>Phases...................................................................................................................................................................................... 35||
||5.3.1|Command Phase....................................................................................................................................................... 35|
||5.3.2|Data Phase................................................................................................................................................................... 36|
||5.3.3|Response Phase....................................................................................................................................................... 37|
||5.4<br>Error Handling....................................................................................................................................................................... 38||
||5.4.1|Command Block Reception Failure................................................................................................................. 38|
||5.4.2|Command Block Invalidity.................................................................................................................................... 38|
||5.4.3|Command Execution Error................................................................................................................................... 38|
|6|Code.................................................................................................................................................................................................... 39||
||6.1<br>ObjectFormatCode............................................................................................................................................................. 39||
||6.1.1|Association Type....................................................................................................................................................... 40|
||6.2<br>Operation Code.................................................................................................................................................................... 41||
||6.2.1|Standard........................................................................................................................................................................ 43|
||6.2.2|Vendor............................................................................................................................................................................. 65|
||6.3<br>Response Code................................................................................................................................................................ 133||
||6.3.1|Standard..................................................................................................................................................................... 134|
||6.3.2|Vendor.......................................................................................................................................................................... 139|
||6.4<br>Event Code......................................................................................................................................................................... 143||
||6.4.1|Standard..................................................................................................................................................................... 144|
||6.4.2|Vendor.......................................................................................................................................................................... 147|
||6.5<br>DevicePropCode.............................................................................................................................................................. 152||
||6.5.1|Standard..................................................................................................................................................................... 158|
||6.5.2|Vendor (Photo Shooting Menu)...................................................................................................................... 178|
||6.5.3|Vendor (Movie Shooting Menu)...................................................................................................................... 231|
||6.5.4|Vendor (Custom Setting Menu)...................................................................................................................... 282|
||6.5.5|Vendor (Setup Menu)........................................................................................................................................... 311|
||6.5.6|Vendor (Power Supply)....................................................................................................................................... 324|
||6.5.7|Vendor (Camera Information).......................................................................................................................... 325|
||6.5.8|Vendor (Bracketing).............................................................................................................................................. 352|
||6.5.9|Vendor (External Flash)...................................................................................................................................... 360|
||6.5.10|Vendor (Lens)........................................................................................................................................................... 377|
||6.5.11|Vendor (USB)........................................................................................................................................................... 384|
||6.5.12|Vendor (Live View)................................................................................................................................................ 386|
||6.5.13|Vendor (Picture Control)..................................................................................................................................... 396|
||6.5.14|Vendor (MTP)........................................................................................................................................................... 399|
||6.6<br>ObjectPropCode............................................................................................................................................................... 400||
||6.6.1|Object Information................................................................................................................................................. 401|
||6.6.2|Thumbnail.................................................................................................................................................................. 412|
||6.6.3|Image Information.................................................................................................................................................. 417|
||6.6.4|Movie Information................................................................................................................................................... 421|
||6.7<br>SBAttributeCode............................................................................................................................................................... 428||
||6.7.1|SBAttribute................................................................................................................................................................. 429|
||6.7.2|SBGroupAttribute................................................................................................................................................... 431|
|7|Data Type....................................................................................................................................................................................... 440||



Do Not Copy 

3/484 

**Confidential** 

## **Confidential** 

## **Nikon Corporation** 

||**Nikon Corporation**|
|---|---|
||7.1<br>DataTypeCode.................................................................................................................................................................. 440|
||7.2<br>Character String Format............................................................................................................................................... 441|
||7.3<br>Date Format........................................................................................................................................................................ 441|
||7.4<br>Array Format...................................................................................................................................................................... 441|
||7.5<br>SBHandle............................................................................................................................................................................. 442|
||7.6<br>SBGroupID.......................................................................................................................................................................... 442|
|8|ObjectHandle............................................................................................................................................................................... 443|
||8.1<br>ObjectHandle of the Object Recorded in the Card......................................................................................... 443|
||8.2<br>ObjectHandle of the Object Recorded in the SDRAM.................................................................................. 443|
||8.3<br>Addition of the ObjectHandle..................................................................................................................................... 443|
|9|DataSet........................................................................................................................................................................................... 444|
||9.1<br>DeviceInfo DataSet......................................................................................................................................................... 444|
||9.2<br>StorageInfo DataSet....................................................................................................................................................... 449|
||9.3<br>ObjectInfo DataSet.......................................................................................................................................................... 450|
||9.3.1<br>Directory/Virtual Association DataSet.......................................................................................................... 451|
||9.3.2<br>Image File DataSet................................................................................................................................................ 452|
||9.3.3<br>Script File DataSet................................................................................................................................................. 453|
||9.3.4<br>Movie File DataSet................................................................................................................................................ 454|
||9.4<br>DevicePropDesc DataSet............................................................................................................................................ 455|
||9.5<br>ObjectPropDesc DataSet............................................................................................................................................. 456|
||9.6<br>Property Description DataSet.................................................................................................................................... 457|
||9.6.1<br>Range Form.............................................................................................................................................................. 457|
||9.6.2<br>Enumeration Form................................................................................................................................................. 457|
||9.6.3<br>Time Form.................................................................................................................................................................. 457|
||9.6.4<br>Fixed-Length Array Form................................................................................................................................... 458|
||9.6.5<br>Regular Expression Form.................................................................................................................................. 458|
||9.6.6<br>Byte String Form..................................................................................................................................................... 458|
||9.6.7<br>LongString Form..................................................................................................................................................... 458|
||9.7<br>LiveViewObject DataSet.............................................................................................................................................. 459|
||9.7.1<br>DataSet with Version............................................................................................................................................ 459|
||9.7.2<br>DataSet without Version..................................................................................................................................... 462|
||9.8<br>PictureControl DataSet................................................................................................................................................. 464|
||9.8.1<br>BasePictureControl............................................................................................................................................... 465|
||9.8.2<br>RegistrationName.................................................................................................................................................. 465|
||9.8.3<br>ApplyLevel................................................................................................................................................................. 466|
||9.8.4<br>QuickSharpFlag...................................................................................................................................................... 467|
||9.8.5<br>QuickSharp................................................................................................................................................................ 467|
||9.8.6<br>Sharpening................................................................................................................................................................ 468|
||9.8.7<br>MiddleRangeSharpening.................................................................................................................................... 468|
||9.8.8<br>Clarity........................................................................................................................................................................... 469|
||9.8.9<br>Contrast....................................................................................................................................................................... 469|
||9.8.10<br>Brightness.................................................................................................................................................................. 470|
||9.8.11<br>Saturation................................................................................................................................................................... 470|
||9.8.12<br>Hue................................................................................................................................................................................ 471|
||9.8.13<br>FilterEffects................................................................................................................................................................ 471|
||9.8.14<br>Toning........................................................................................................................................................................... 472|
||9.8.15<br>ToningDensity........................................................................................................................................................... 472|
||9.8.16<br>CustomCurveFlag.................................................................................................................................................. 473|



Do Not Copy 

4/484 

**Confidential** 

## **Confidential** 

## **Nikon Corporation** 

|**Confidential**<br>**Nikon Corporation**|**Confidential**<br>**Nikon Corporation**|
|---|---|
|9.8.17<br>CustomCurveData................................................................................................................................................. 473||
|9.9|PictureControlCapability DataSet............................................................................................................................ 474|
|9.9.1<br>DefaultLevel.............................................................................................................................................................. 474||
|9.10|SBAttributeDesc DataSet............................................................................................................................................ 475|
|9.11|SBAttributeDescList DataSet..................................................................................................................................... 475|
|9.12|SBAttribute DataSet....................................................................................................................................................... 476|
|9.13|SBAttributeList DataSet................................................................................................................................................ 476|
|10|Data Format........................................................................................................................................................................ 477|
|10.1|ASCII Codes....................................................................................................................................................................... 477|
|11|Appendices......................................................................................................................................................................... 478|
|11.1|Properties Affected by Mounting the CPU Lens.............................................................................................. 478|
|11.2|Properties Affected by Mounting the External Flash...................................................................................... 478|
|11.3|Properties Affected by the Shooting Mode......................................................................................................... 479|
|11.4|Properties Affected by Time Zone........................................................................................................................... 480|
|11.5|White Balance Fine Tuning Coordinates............................................................................................................. 481|
|11.6|External Flash Types...................................................................................................................................................... 482|
|11.7|Command Release Operation................................................................................................................................... 483|
|11.7.1<br>Continuous Shooting............................................................................................................................................ 483||
|11.7.2<br>AF Operation............................................................................................................................................................ 483||
|11.7.3<br>Preset WB acquisition.......................................................................................................................................... 483||
|11.7.4<br>Event on the Release Operation.................................................................................................................... 484||
|11.7.5<br>Recovery from the Sequence Error.............................................................................................................. 484||
|11.7.6<br>Silent Shooting........................................................................................................................................................ 484||



Do Not Copy 

5/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **1 Introduction** 

## **1.1 Application** 

These specifications describe the operations of the Z 6_2 (hereinafter referred to as the camera) as the USB Still Image Capture Device. 

The specifications of the USB Still Image Capture Device are defined by “MTP Specification v1.0 - Media Transfer Protocol (MTP)” and the camera is based on it. 

The camera conforms to the USB-related specifications below.  For the details of each specification, refer to the related specifications manual. 

|Item|Contents|
|---|---|
|USBspecifications|Revision3.0|
|Class|Image Interface|
|Subclass|Still Image Capture Device|
|Protocol|Bulk-Only Transport Protocol|



Do Not Copy 

6/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2 Outline** 

## **2.1 PC Connection Mode** 

When the camera is connected to the PC, the camera is switched to the PC connection mode. 

## **2.2 PC Connection Mode and Camera Operations** 

The operations of the camera in the PC connection mode differ from those of the camera alone in the following points. 

|No.|Description|
|---|---|
|1|When the remote mode is set (the camera is controlled by the PC), the operations by the dials<br>and buttons of the camera body are locked with some exceptions.  (Refer to subsection 2.4.)|
|2|The captured images are recorded either in the card or in the SDRAM.  (Refer to subsection<br>2.5.)|
|3|The image playback cannot be performed.  The image deletion by operating the camera body<br>also cannot be performed.  (Except in the application mode)|
|4|TheAutometer-offdelayis set to“Nolimit”.|



## **2.3 PC Camera Mode and Remote Mode** 

The PC connection mode has the PC camera mode and the remote mode, and the camera is set to the PC camera mode when it is connected to the PC.  Switching between the PC camera mode and the remote mode is performed by the command processing routine in the camera automatically for each command sent from the host or by the ChangeCameraMode command defined as a vendor command. 

If a command for which changing the PC camera mode to the remote mode is necessary is issued while the remote mode is specified by the ChangeCameraMode command, the remote mode is retained even when the command processing is terminated. 

During switching to the remote mode by the ChangeCameraMode command, the operation of each dial or button is ignored and the value set by the host is valid.  When switching to the PC camera mode, the values set by the host in the remote mode are canceled and those set by each dial or button are used.  For the setting value of each dial or button when switching to the remote mode, the value set by each dial or button becomes the initial value. 

## **2.4 Application Mode** 

The camera is switched to the application mode by the ChangeApplicationMode property.  At this time, the StoreRemoved event is passed. 

In the application mode by the PC camera mode, the image playback, deletion and the movie recording can be performed on the camera. 

The host, which acquires the events by using the GetEventEx command, can acquire all the events generated in the application mode. 

The host, which acquires the events by using the Interrupt IN transfer, can acquire only the DevicePropChanged event of the standard property. 

Do Not Copy 

7/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.5 Recording Destination** 

The camera supports the following three methods for the recording destinations of the image data when the images are acquired by using the shutter-release button of the camera or the release request command from the host during the USB connection. 

|No.|Description|
|---|---|
|1|Records in the card (default).|
|2|Transfers to the host (records in the SDRAM temporarily).|
|3|Records in the card and transfers to the PC simultaneously.|



The camera has the RecordingMedia property (subsection 6.5.7.3) to save the recording destination setting.  The RecordingMedia property can be changed only by issuing the command from the host. 

The recording destination set in the RecordingMedia property is effective only when the image is captured by using the shutter-release button of the camera, and it is not effective for the shooting request command from the host.  For the shooting request command from the host, the recording destination differs depending on the request command. 

|・<br>・|When the image is captured by using the shutter-release button of the camera|When the image is captured by using the shutter-release button of the camera|When the image is captured by using the shutter-release button of the camera|
|---|---|---|---|
||RecordingMedia property||Operations|
||Card||The captured data are recorded in the card.|
||SDRAM||The captured data are recorded in the SDRAM temporarily and<br>transferred to the host.|
||Card and SDRAM||Operation with the recording destination set to the card and that<br>with the recording destination set to the SDRAM are both<br>performed.|
||When the image is captured by using the release request command from the host|||
||RecordingMedia property|Operations||
||InitiateCapture|The captured data are recorded in the card.||
||InitiateCaptureRecInSdram|The captured data are recorded in the SDRAM temporarily and<br>transferred to thehost.||
||AfAndCaptureRecInSdram|Operation with the recording destination set to the card and that with<br>the recording destination set to the SDRAM are both performed.||
||InitiateCaptureRecInMedia|The following three operations can be performed by specifying the<br>parameter.||
|||1: The captured data are recorded in the card.||
|||2: The captured data are recorded in the SDRAM temporarily and<br>transferred to the host.||
|||3: The captured data are recorded in the card and the SDRAM, and<br>thoserecordedinthe SDRAMare transferred to thehost.||



If the host is incapable of image acquisition operation by the SDRAM recording shown in subsection 2.7, the value of the RecordingMedia property must not be changed. 

The host must return the changed value of the RecordingMedia property to [Card] when terminating the use of the camera by communication. 

Do Not Copy 

8/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.5.1 Access to the Card** 

During the USB connection, the insertion/ejection, existence/nonexistence, capacity, and the type of the card are detected by the camera.  For the access to the card, the file system of the camera is always used and that of the host is not used.  Therefore the host can access the card only after the USB connection is performed and the initialization of the information in the card is completed. During the USB connection, even if the card does not exist and then it is inserted, the host cannot access the data in the card until the initialization of the card information is completed. 

The file system conforms to the DCF.  The DPOF specification is also supported.  Therefore the host cannot access the card with the directory structure or the file structure that does not conform to the DCF or the DPOF specification. 

The host can read the data in the card, but cannot write the data to the card. 

The camera can make the deletion of data in the card and perform card formatting by the command from the host. 

When the captured images are being recorded on the card, the data deletion and the card formatting cannot be performed until all the images are recorded on the card.  The release operation by the shutter-release button of the camera and the shooting request command cannot be executed during the data deletion and the card formatting. 

## **2.5.2 Access to the SDRAM** 

When accessing the image data recorded in the SDRAM, accessing can be performed only to the one image data that is ready to be taken in and to the oldest image data in order of storage in the SDRAM.  The image data in the SDRAM cannot be accessed randomly.  (Refer to subsection 8.2). 

The image data sent to the host completely is erased from the SDRAM. 

Do Not Copy 

9/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.6 Sending the Event** 

When the status in the camera is changed, the camera sends an event by the Interrupt transfer to notify the host of the contents of the change.  However, the host may not be able to get the event sent by the camera depending on the OS type of the PC (host).  Therefore the camera provides two methods of getting the event. 

All the generated events can be acquired in order of generation by either of the two methods. The methods are shown below. 

|No.|Description|
|---|---|
|1|Sending the event by the Interrupt transfer (based on the PTP specifications)|
|2|Sending the event by the GetEventEx command (vendor-defined)|



The camera stores the event generated in the camera in order in the queue buffer and retains the queue buffer status until the event is acquired by the host.  The camera is provided with two queue buffers for the two methods of getting the event. 

It is necessary for the host to use only one of the two methods of acquiring the event to perform the event processing.  The camera does not manage the coordination of the two queue buffers. 

When the queue buffer that is not used for the event acquisition becomes full, the camera deletes the old event from the queue buffer and stores the new event in the queue buffer. 

For sending the event in the application mode, refer to “Application Mode” (subsection 2.4). 

Do Not Copy 

10/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.7 Shooting Operation and Image Data Acquisition in the PC Connection Mode** 

While the session is open in the PC connection mode, the camera performs the shooting operation by the command from the host or the shutter-release button of the camera.  The captured images are stored in the card or the SDRAM by the command from the host or the setting value of the recording destination property (refer to subsection 2.5). 

The host can acquire the saved image data by the GetObject or the GetPartialObject command. 

## **2.7.1 Command Sequence (Recording in the Card)** 

The command sequence leading from the recording of the captured image data in the card to the data acquisition by the host is shown below. 

|No.|Description|
|---|---|
|1|When acquiring the event by the command, the host issues the GetEventEx command regularly<br>to acquire the event.|
|2|The host issues the InitiateCapture command or the InitiateCaptureRecInMedia command to<br>capture the image data.  The camera performs the single shot operation or the continuous shot<br>operation according to the shooting mode setting.|
|3|When the captured image data is saved in the card, the camera issues the ObjectAdded event.<br>The objecthandleindicating the savedimage datais added to the ObjectAdded event.|
|4|If the continuous shot operation is set, the camera repeats the procedure in (3) as many times as<br>the number of shooting.|
|5|The camera issues the CaptureComplete event when all the image data captured by the<br>InitiateCapture command or the InitiateCaptureRecInMedia command are saved completely.|
|6|The host acquires the image data information by issuing the GetObjectInfo command.|
|7|The host acquires the thumbnail data by issuing the GetThumb and the GetLargeThumb<br>commands, if necessary.|
|8|The host acquires the image data by issuing the GetObject or GetPartialObject command.|
|9|When two or more image data are saved by the continuous shot operation, the host repeats the<br>procedures in (6) to (8) to acquire all the image data.|



## **2.7.2 Command Sequence (Recording in the SDRAM)** 

The command sequence leading from the recording of the captured image data in the SDRAM to the data acquisition by the host is shown below. 

|No.|Description|
|---|---|
|1|When acquiring the event by the command, the host issues the GetEventEx command regularly<br>to acquire the event.|
|2|The host issues the InitiateCaptureRecInSdram, the AfAndCaptureRecInSdram, or the<br>InitiateCaptureRecInMedia command to capture the image data.  The camera performs the<br>single shot operation or the continuous shot operation according to the shooting mode setting.|
|3|The host issues the DeviceReady command repeatedly while executing the operations in (4) and<br>after.|
|4|The host waits for the camera to issue the ObjectAddedInSdram event.|
|5|The camera saves the captured image data in the SDRAM in order, and issues the<br>ObjectAddedInSdram event in sequence when the sending of image data to the host becomes<br>enabled.|
|6|The host acquires the image data information by issuing the GetObjectInfo command.|
|7|The host acquires the thumbnail data by issuing the GetThumb and the GetLargeThumb<br>commands, if necessary.|
|8|Thehost acquires theimage data byissuing the GetObject orGetPartialObject command.|
|9|The host repeats the procedures in (6) to (8) as many times as the number of received<br>ObjectAddedInSdram events.|
|10|When<br>all<br>the<br>image<br>data<br>captured<br>by<br>one<br>InitiateCaptureRecInSdram,<br>the<br>AfAndCaptureRecInSdram, or the InitiateCaptureRecInMedia command are sent completely, the<br>camera sends the CaptureCompleteRecInSdram event.|



Do Not Copy 

11/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.7.3 Command Sequence (Recording by the Shutter-Release Button of the Camera)** 

The command sequence leading from the capture of the image data by the shutter-release button of the camera to the acquisition of the recorded image data is shown below. 

|No.|Description|
|---|---|
|1|When acquiring the event by the command, the host issues the GetEventEx command regularly<br>to acquire the event.|
|2|The shooting operation is performed by the shutter-release button of the camera.  The camera<br>performs the shooting operation (single shot operation, the continuous shot operation, or the<br>interval-timer shooting) according to the shooting mode setting.|
|3|The camera saves the images in the card, the SDRAM, or the card and the SDRAM according to<br>the setting oftherecording destinationproperty.|
|4|When the images are saved in the card, the procedures in (5) to (10) should be performed.<br>When the images are saved in the SDRAM, the procedures in (11) to (15) should be performed.|
|5|When the captured image data is saved in the card, the camera issues the ObjectAdded event.<br>The object handle indicating the saved image data is added to the ObjectAdded event.|
|6|If the continuous shot operation is set, the camera repeats the procedure in (3) as many times as<br>thenumberofshooting.|
|7|The host acquires the image data information by issuing the GetObjectInfo command.|
|8|The host acquires the thumbnail data by issuing the GetThumb and the GetLargeThumb<br>commands, if necessary.|
|9|The host acquires the image data by issuing the GetObject or GetPartialObject command.|
|10|When two or more image data are saved by the continuous shot operation, the host repeats the<br>procedures in (11) to (14) to acquire all the image data.|
|11|The camera saves the captured image data in the SDRAM in order, and issues the<br>ObjectAddedInSdram event in sequence when the sending of image data to the host becomes<br>enabled.|
|12|The host acquires the image data information by issuing the GetObjectInfo command.|
|13|The host acquires the thumbnail data by issuing the GetThumb and the GetLargeThumb<br>commands, if necessary.|
|14|The host acquires the image data by issuing the GetObject or GetPartialObject command.|
|15|The host repeats the procedures in (12) to (15) as many times as the number of received<br>ObjectAddedInSdram events.|



## **2.7.4 Command Sequence (Bulb Shooting)** 

|**4 Command Sequence (Bulb Shooting)**|**4 Command Sequence (Bulb Shooting)**|
|---|---|
|he command sequence to acquire the image data recorded by Bulb shooting is shown below||
|No.|Description|
|1|The host changes the camera to the remote mode by using the ChangeCameraMode command.|
|2|Thehost sets“M”by using theExposureProgramMode property.|
|3|The host sets Bulb shooting (0xFFFFFFFF) by using the ExposureTime property and the<br>ShutterSpeed property.|
|4|Thehostissues theInitiateCaptureRecInMedia command to start shooting.|
|5|The host issues the DeviceReady command and confirms that the response code is<br>Bulb_Release_Busy.|
|6|Thehostissues theTerminateCapture command to terminateBulb shooting.|
|7|The camera records the created images in the card, the SDRAM, or the card and the SDRAM after<br>completion of the shooting and issues the ObjectAdded event or the ObjectAddedInSdram event to<br>thehost.|
|8|The host acquires the ObjectAdded event or the ObjectAddedInSdram event by the GetEventEx<br>command to acquire the ObjectHandle of the created images.|
|9|Thehost acquires theimageinformationby the GetObjectInfo command.|
|10|The host acquires the thumbnail image by the GetThumb and the GetLargeThumb commands, if<br>necessary.|
|11|The host acquires the image data by issuing the GetObject or GetPartialObject command.|
|12|The camera issues the CaptureComplete event or the CaptureCompleteRecInSdram event.|
|13|The host acquires the CaptureComplete event or the CaptureCompleteRecInSdram event by the<br>GetEventEx command.|
|14|The host changes the camera to the PC camera mode by using the ChangeCameraMode<br>command.|



Do Not Copy 

12/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.8 Live View Image and Data Acquisition in the PC Connection Mode** 

When the session is open in the PC connection mode, the camera starts the live view by the request from the host. 

During the remote live view after the host executed the StartLiveView command, the live view images can be acquired by the GetLiveViewImageEx command. 

## **2.8.1 Command Sequence** 

The command sequence leading from the start of live view by the request from the host to the acquisition of the live view image is shown below. 

|No.|Description|
|---|---|
|1|The host issues the StartLiveView command to request the camera to start the remote live view.|
|2|After confirming the normal termination of the StartLiveView command, the host issues the<br>DeviceReady command repeatedly until the DeviceReady command response other than<br>Device_Busy appears.|
|3|The camera returns the normal termination response to the DeviceReady command when the live<br>view image acquisition becomes enabled.  If the live view image acquisition is disabled for some<br>reason, the camera returns an error response to the DeviceReady command to terminate the live<br>view.|
|4|After confirming the normal termination of the DeviceReady command response, the host issues<br>the GetLiveViewImageEx command to acquire the live view image.|
|5|The host issues the GetLiveViewImageEx command repeatedly while the live view continues.  At<br>this time, the AF driving (AfDrive command), the MF driving (MfDrive command), the AF area<br>change (ChangeAfArea command), etc.canbe performed optionally.|
|6|When the remote live view is finished, the host issues the EndLiveView command.|



Do Not Copy 

13/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.8.2 Command Sequence (Movie Recording)** 

The sequence leading from the recording of the movie in the card by the MovieRec command to the acquisition of the movie file is shown below. 

|No.|Description|
|---|---|
|1|The host issues MovieRecProhibitionCondition during the movie live view execution to confirm that<br>movie recording can be performed.|
|2|The host issues the StartMovieRecord command to start the movie recording.|
|3|The camera stops the movie recording or the host issues the EndMovieRecord command to stop<br>themovierecording.|
|4|The camera writes the captured movie file in the card and issues the ObjectAdded event.|
|5|The camera issues the MovieRecordComplete event after stopping movie recording.|
|6|The host acquires the MovieRecordComplete event by the GetEventEx command.|
|7|The host acquires the ObjectAdded event by the GetEventEx command to acquire the<br>ObjectHandle of the movie file.|
|8|The host acquires the file size of the movie file by the GetObjectInfo command.|
|9|The host divides and acquires the movie file by the GetPartialObject command.<br>When the movie file is acquired by the GetObject command, the control from the host cannot be<br>performed until the file transfer is finished because the file size of the movie file is large.<br>Therefore, use the GetPartialObject command.|



## **2.8.3 Command Sequence (Over 4GB Movie Transfer)** 

The command sequence to transfer the movie data over 4GB is shown below. 

|No.|Description|
|---|---|
|1|The host issues MovieRecProhibitionCondition during the movie live view execution to confirm that<br>movie recording can be performed.|
|2|Thehostissues the StartMovieRecord command to start themovierecording.|
|3|The camera stops the movie recording or the host issues the EndMovieRecord command to stop<br>the movie recording.|
|4|The camerawrites the capturedmoviefileinthe card andissues the ObjectAdded event.|
|5|The camera issues the MovieRecordComplete event after stopping movie recording.|
|6|The host acquires the MovieRecordComplete event by the GetEventEx command.|
|7|The host acquires the ObjectAdded event by the GetEventEx command to acquire the<br>ObjectHandle of the movie file.|
|8|The host acquires the file size of the movie file by the GetObjectInfo command.<br>When the file size of the GetObjectInfo command is 0xFFFFFFFF, use the following method to get<br>the file size.<br>PTP: Use GetObjectSize command to get the file size.<br>MTP:Use ObjectSize ofthe GetObjectPropValue command to get thefile size.|
|9|The host divides and acquires the movie file by the GetPartialObjectHighSpeed or<br>GetPartialObjectEx command.<br>When the movie file is acquired by the GetObject command, the control from the host cannot be<br>performed until the file transfer is finished because the file size of the movie file is large.<br>Therefore, use the GetPartialObjectHighSpeed or GetPartialObjectEx command.|



Do Not Copy 

14/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.8.4 Command Sequence (Spot WB)** 

The command sequence to acquire the spot WB by the MeasureSpotWB command and set it to preset manual is shown below. 

|No.|Description|
|---|---|
|1|The host issues the StartLiveView command to request the camera to start the remote live view.|
|2|Thehost changes the camera to theremotemode by using the ChangeCameraMode command.|
|3|The host sets WhiteBalance to Preset manual.|
|4|The host sets WbPresetDataNo in which the spot WB is saved.  At this time, a WbPresetDataNo<br>in which Presetmanual is protectedmustnot be set.|
|5|The host issues the StartSpotWb command to request the camera to start the spot WB acquisition<br>standby state.  Confirm the spot WB condition of LiveViewObject that can be acquired by the<br>GetLiveViewImageExcommand to check whetherthe spotWBacquisitionstandby stateis started.|
|6|The host sets the area to be acquired by ChangeSpotWbArea.|
|7|The host issues the MeasureSpotWb command to acquire the spot WB.  Confirm the spot WB<br>conditionof LiveViewObject to checkthe acquisition result.|
|8|If the acquisition succeeds, the camera cancels the spot WB acquisition standby state and sets the<br>spot WB condition of LiveViewObject to“On standby”(acquisition success) for three seconds.|
|9|If the acquisition fails, the camera remains in the spot WB acquisition standby state and sets the<br>spot WB condition of LiveViewObject to“On standby”(acquisition failure) for five seconds.|
|10|The host issues the EndSpotWbResultDisp command to cancel the spot WB acquisition result<br>display quickly.|
|11|The host issues the EndSpotWb command to terminate the spot WB acquisition standby state.|
|12|The host changes the camera to the PC camera mode by using the ChangeCameraMode<br>command.|



Do Not Copy 

15/484 

**Confidential** 

**Nikon Corporation** 

## **Confidential** 

The transition of the spot WB condition that can be acquired by GetLiveViewImageEx command is shown below. 

**==> picture [405 x 424] intentionally omitted <==**

**----- Start of picture text -----**<br>
0<br>StartSpotWb<br>ChangeSpotWbArea<br>1<br>MeasureSpotWb<br>3second or EndSpotWbResultDisp 5second or EndSpotWbResultDisp<br>2<br>MeasureSpotWb<br>3 4<br>**----- End of picture text -----**<br>


The figures in the diagram above show “Spot WB condition” of LiveViewObject acquired by the GetLiveViewImageEx command. 

Do Not Copy 

16/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.8.5 Command Sequence (Tracking)** 

The command sequence from tracking start to tracking end is shown below. 

|No.|Description|
|---|---|
|1|Thehostissues the StartLiveViewcommand torequest the camera to start theremoteliveview.|
|2|The host sets the AF area mode to Auto-area AF.|
|3|The host can execute the following commands to change the tracking state.<br>- StartTracking command<br>The host issues the StartTracking command with the area where you want to start tracking as the<br>parameters.<br>When no face is detected at the specified coordinates, the camera sets the tracking state of<br>LiveViewObject to "On tracking" and starts tracking operation at the specified coordinates.<br>When a face is detected at the specified coordinates, the camera updates the selected face index.<br>At this time, the tracking state changes to the standby state.<br>When the StartTracking command is executed with "On tracking" in the tracking state, the camera<br>starts tracking operation at the specified coordinates with or without detected face.<br>- AfDrive command<br>In the case that the tracking state is being selected, the camera changes the tracking state to "On<br>tracking" when starting AF driving.<br>- InitiateCaptureRecInMedia command<br>In the case that the tracking state is being selected and the command is executed when "Image<br>acquisition release after AF driving" is specified for CaptureSort, the camera changes the tracking<br>state to "On tracking" when starting AF driving and starts the release operation.  After the release<br>operation is completed, the tracking state changed immediately before is maintained.|
|5|Thehostissues theEndTracking command to end tracking action.|



* Whether the tracking state has changed or not is confirmed by checking the tracking state of LiveViewObject acquired by the GetLiveViewImageEx command. 

Do Not Copy 

17/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **2.9 Reacquisition of the Image Data** 

When one of the following occurs during the reading sequence of the image data recorded in the SDRAM in subsections 2.7.2 and 2.7.3, the host can redo the image data acquisition by issuing the GetObjectInfo command. 

|No.|Description|
|---|---|
|1|The USB connection is cut.  (Such as the case that the USB cable is extracted.)|
|2|The camera returns an error to the GetObject or the GetPartialObject command.|
|3|It is desirable for the host to redo the acquisition of the SDRAM image.|



When the image data that is not sent yet exists in the SDRAM, the camera must retain it even if the USB connection is cut. 

If the shooting has been performed with “RAW+JPEG” and either of the image data has been sent normally, only the other image data should be sent again. 

## **2.10 Operation with the Empty Battery** 

When the battery is exhausted, the camera cannot detect the card and notify the host of no card status even if it is inserted. 

Do Not Copy 

18/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **3 Device Re uests q** 

## **3.1 Standard Device Requests** 

|Request||wIndex||
|---|---|---|---|
|||Data stage|Status stage|
|Get Status|Device|The current device power<br>status and the setting of<br>REMOTE_WAKEUP function|Receive NULL data|
||Endpoint: Endpoint number that is<br>supported|The current<br>ENDPOINT_STALL status|Receive NULL data|
||Endpoint: Endpoint number that is not<br>supported|STALL response|-|
|Clear Feature|Device: DEVICE_REMOTE_WAKEUP|-|Return NULL data|
||Endpoint: END_POINT_HALT<br>Endpointnumberthatis supported|-|Return NULL data|
||Endpoint: END_POINT_HALT<br>Endpoint number that is not supported|-|STALL response|
|Set Feature|Device: DEVICE_REMOTE_WAKEUP|-|Return NULLdata|
||Endpoint: END_POINT_HALT<br>Endpoint number that is supported|-|Return NULL data|
||Endpoint: END_POINT_HALT<br>Endpoint number that is not supported|-|STALL response|
|Set Address||-|Return NULL data|
|GetDescriptor||The specified descriptor|ReceiveNULLdata|
|Set Descriptor||STALL response|-|
|Get Configuration||The current configuration<br>value|Return NULL data|
|Set<br>Configuration|Configuration number that is supported|-|Return NULL data|
||Configuration numberthatisnot supported|-|STALL response|
|Set Interface|Interface number and alternate number<br>that are supported|-|Return NULL data|
||Interface number and alternate number<br>that are not supported|-|STALL response|
|Get Interface|Interface number that is supported|The current alternate value|Return NULL data|
||Interfacenumberthatisnot supported|STALL response|-|
|Synch Frame||STALL response|-|



Do Not Copy 

19/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **3.2 Class-Specific Requests** 

The camera supports the class-specific requests below. 

## **3.2.1 Cancel Request** 

This request is used for the host to cancel the data transfer. 

|bmRequestType|bRequest|wValue|wIndex|wLength|
|---|---|---|---|---|
|00100001b|01100100b|0000h|0000h|06h|



The camera receives the Cancel request data according to the following format. 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|Cancellation Code|2|Code|0x4001|
|2|TransactionID|4|Number|TransactionID|



The camera cancels the command processing that corresponds to the TransactionID. 

## **3.2.2 DeviceReset Request** 

This request is sent from the host to the camera in order to make the device become in the idle status when the Bulk Pipe is stalled. 

|bmRequestType|bRequest|wValue|wIndex|wLength|
|---|---|---|---|---|
|00100001b|01100110|0000h|0000h|0|



## **3.2.3 GetDeviceStatus Request** 

This request is used for the host to acquire the device information for the recovery of the endpoint that is in the halt status. 

|bmRequestType|bRequest|wValue|wIndex|wLength|
|---|---|---|---|---|
|10100001b|01100110|0000h|0000h|0|



The camera sends the GetDeviceStatus request data according to the following format. 

|Field|Size|Value|Description|
|---|---|---|---|
|WLength|2|Number|4|
|Code|2|Code|0x2001: Status OK<br>0x2019: DeviceBusy|



Do Not Copy 

20/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4 Descri tors p** 

## **4.1 Standard Descriptors** 

The camera has the following standard descriptors. 

## **4.1.1 Device Descriptor** 

## **4.1.1.1 HIGH-SPEED** 

## **USB 2.x** 

|**USB 2.x**|**USB 2.x**|**USB 2.x**|**USB 2.x**|**USB 2.x**|
|---|---|---|---|---|
|Offset|Field|Size|Value|Description|
|0|bLength|1|12h|Size ofthe descriptor|
|1|bDescriptorType|1|01h|Type of the descriptor (Device descriptor)|
|2|bcdUSB|2|0210h|USB specification number (0210h=Revision 2.10)|
|4|bDeviceClass|1|00h|Class (specified by the interface descriptor)|
|5|bDeviceSubClass|1|00h|Subclass (specified by the interface descriptor)|
|6|bDeviceProtocol|1|00h|Protocol(specified by theinterface descriptor)|
|7|bMaxPacketSize0|1|40h|Maximum packet size of endpoint 0|
|8|idVendor|2|04B0h|Vendor ID (“NIKON”)|
|10|idProduct|2|044Ch|Product ID|
|12|bcdDevice|2|0100h|Device release number (0100h=1.00)|
|14|iManufacture|1|01h|Indexofthe string descriptordescribing themanufacturer name|
|15|iProduct|1|02h|Index of the string descriptor describing the product name|
|16|iSerialNumber|1|03h|Indexofthe string descriptordescribing the serial number|
|17|bNumConfigurations|1|01h|The number of configurations|



|**USB 3.x**|**USB 3.x**||||
|---|---|---|---|---|
|Offset|Field|Size|Value|Description|
|0|bLength|1|12h|Size of the descriptor|
|1|bDescriptorType|1|01h|Type of the descriptor (Device descriptor)|
|2|bcdUSB|2|0320h|USBspecification number(0320h=Revision3.20)|
|4|bDeviceClass|1|00h|Class (specified by the interface descriptor)|
|5|bDeviceSubClass|1|00h|Subclass (specified by the interface descriptor)|
|6|bDeviceProtocol|1|00h|Protocol (specified by the interface descriptor)|
|7|bMaxPacketSize0|1|09h|Maximum packet size of endpoint 0|
|8|idVendor|2|04B0h|Vendor ID(“NIKON”)|
|10|idProduct|2|044Ch|Product ID|
|12|bcdDevice|2|0100h|Devicereleasenumber(0100h=1.00)|
|14|iManufacture|1|01h|Index of the string descriptor describing the manufacturer name|
|15|iProduct|1|02h|Index of the string descriptor describing the product name|
|16|iSerialNumber|1|03h|Indexofthe string descriptordescribing the serial number|
|17|bNumConfigurations|1|01h|The number of configurations|



Do Not Copy 

21/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.1.1.2 FULL-SPEED** 

|**USB 2.x**|**USB 2.x**||||
|---|---|---|---|---|
|Offset|Field|Size|Value|Description|
|0|bLength|1|12h|Size ofthe descriptor|
|1|bDescriptorType|1|01h|Type of the descriptor (Device descriptor)|
|2|bcdUSB|2|0210h|USB specification number (0210h=Revision 2.10)|
|4|bDeviceClass|1|00h|Class (specified by the interface descriptor)|
|5|bDeviceSubClass|1|00h|Subclass (specified by the interface descriptor)|
|6|bDeviceProtocol|1|00h|Protocol(specified by theinterface descriptor)|
|7|bMaxPacketSize0|1|40h|Maximum packet size of endpoint 0|
|8|idVendor|2|04B0h|Vendor ID (“NIKON”)|
|10|idProduct|2|044Ch|Product ID|
|12|bcdDevice|2|0100h|Device release number (0100h=1.00)|
|14|iManufacture|1|01h|Indexofthe string descriptordescribing themanufacturer name|
|15|iProduct|1|02h|Index of the string descriptor describing the product name|
|16|iSerialNumber|1|03h|Indexofthe string descriptordescribing the serial number|
|17|bNumConfigurations|1|01h|The number of configurations|



|**USB 3.x**|**USB 3.x**||||
|---|---|---|---|---|
|Offset|Field|Size|Value|Description|
|0|bLength|1|12h|Size of the descriptor|
|1|bDescriptorType|1|01h|Type ofthe descriptor(Device descriptor)|
|2|bcdUSB|2|0320h|USB specification number (0320h=Revision 3.20)|
|4|bDeviceClass|1|00h|Class (specified by the interface descriptor)|
|5|bDeviceSubClass|1|00h|Subclass (specified by the interface descriptor)|
|6|bDeviceProtocol|1|00h|Protocol (specified by the interface descriptor)|
|7|bMaxPacketSize0|1|09h|Maximumpacket size ofendpoint 0|
|8|idVendor|2|04B0h|Vendor ID (“NIKON”)|
|10|idProduct|2|044Ch|Product ID|
|12|bcdDevice|2|0100h|Device release number (0100h=1.00)|
|14|iManufacture|1|01h|Index of the string descriptor describing the manufacturer name|
|15|iProduct|1|02h|Indexofthe string descriptordescribing the productname|
|16|iSerialNumber|1|03h|Index of the string descriptor describing the serial number|
|17|bNumConfigurations|1|01h|Thenumberofconfigurations|



Do Not Copy 

22/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.1.2 Device_Qualifier Descriptor** 

|**USB 2.x**|**USB 2.x**||||
|---|---|---|---|---|
|Offset|Field|Size|Value|Description|
|0|bLength|1|0Ah|Size of the descriptor|
|1|bDescriptorType|1|06h|Type of the descriptor (Device_Qualifier descriptor)|
|2|bcdUSB|2|0210h|USBspecification number(0210h=Revision 2.10)|
|4|bDeviceClass|1|00h|Class (specified by the interface descriptor)|
|5|bDeviceSubClass|1|00h|Subclass (specified by the interface descriptor)|
|6|bDeviceProtocol|1|00h|Protocol (specified by the interface descriptor)|
|7|bMaxPacketSize0|1|40h|Maximum packet size of endpoint 0|
|8|bNumComfigurations|1|01h|Thenumberofconfigurations otherthanUSB2.0|
|9|bReserved|1|00h|Reserved|



|**USB 3.x**|**USB 3.x**||||
|---|---|---|---|---|
|Offset|Field|Size|Value|Description|
|0|bLength|1|0Ah|Size of the descriptor|
|1|bDescriptorType|1|06h|Type of the descriptor (Device_Qualifier descriptor)|
|2|bcdUSB|2|0210h|USB specification number (0210h=Revision 2.10)|
|4|bDeviceClass|1|00h|Class (specified by the interface descriptor)|
|5|bDeviceSubClass|1|00h|Subclass (specified by theinterface descriptor)|
|6|bDeviceProtocol|1|00h|Protocol (specified by the interface descriptor)|
|7|bMaxPacketSize0|1|40h|Maximumpacket size ofendpoint 0|
|8|bNumComfigurations|1|01h|The number of configurations other than USB2.0|
|9|bReserved|1|00h|Reserved|



Do Not Copy 

23/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.1.3 Configuration Descriptor** 

|Offset|Field|Size|Value|Description|Description|
|---|---|---|---|---|---|
|0|bLength|1|09h|Size of the descriptor||
|1|bDescriptorType|1|02h|Type of the descriptor (Configuration descriptor)||
|2|wTotalLength|2|0027h|The total length of the data returned for this configuration<br>All the descriptors are included (configuration, interface, endpoint,<br>and class-specific).<br>Total length is 0039h when the SuperSpeed is used.||
|4|bNumInterfaces|1|01h|The number of interfaces||
|5|bConfiguration<br>Value|1|01h|The value used as an argument to Set Configuration Request for<br>selecting this configuration||
|6|iConfiguration|1|00h|Index of the string descriptor||
|7|bmAttributes|1|C0h|Configuration characteristics||
|||||Bit7|Reserved (1)|
|||||Bit6|Self-powered|
|||||Bit5|Remote Wakeup|
|||||Bit4…0|Reserved (0)|
|8|MaxPower|1|FAh|Maximum power consumption supplied from the bus to the USB<br>device (2 mA).<br>003fh(8mA)forSuperSpeed.||



## **4.1.4 Other_Speed_Configuration Descriptor** 

|Offset|Field|Size|Value|Description|Description|
|---|---|---|---|---|---|
|0|bLength|1|09h|Size of the descriptor||
|1|bDescriptorType|1|07h|Type of the descriptor (OtherSpeedConfiguration descriptor)||
|2|wTotalLength|2|0027h|The total length of the data returned for this configuration<br>All the descriptors are included (configuration, interface, endpoint,<br>and class-specific).||
|4|bNumInterfaces|1|01h|Thenumberof interfaces||
|5|bConfiguration<br>Value|1|01h|The value used as an argument to Set Configuration Request for<br>selecting this configuration||
|6|iConfiguration|1|00h|Indexofthe string descriptor||
|7|bmAttributes|1|C0h|Configuration characteristics||
|||||Bit7|Reserved (1)|
|||||Bit6|Self-powered|
|||||Bit5|Remote Wakeup|
|||||Bit4…0|Reserved(0)|
|8|MaxPower|1|FAh|Maximum power consumption supplied from the bus to the USB<br>device (2 mA)||



Do Not Copy 

24/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.1.5 Interface Descriptor** 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|09h|Size of the descriptor|
|1|bDescriptorType|1|04h|Type of the descriptor (Interface descriptor)|
|2|bInterfaceNumber|1|00h|Interface number (0 is the standard.)|
|3|bAlternatingSetting|1|00h|Thevalue usedforselecting theinterface|
|4|bNumEndpoints|1|03h|The number of endpoints|
|5|bInterfaceClass|1|06h|Class code (06=ImageInterface)|
|6|bInterfaceSubClass|1|01h|Subclass code (01=Still Image Capture Device)|
|7|bInterfaceProtocol|1|01h|Protocol (01h=Bulk-Only Transport)|
|8|iInterface|1|00h|Indexofthe string descriptordescribing thisinterface|



Do Not Copy 

25/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.1.6 Endpoint Descriptor** 

## **4.1.6.1 Bulk-Out Endpoint** 

## For SUPER-SPEED 

|Offset|Field|Size|Value|Description|Description|
|---|---|---|---|---|---|
|0|bLength|1|07h|Size ofthe descriptor||
|1|bDescriptorType|1|05h|Type of the descriptor (Endpoint descriptor)||
|2|bEndpointAddress|1|02h|Address of the endpoint||
|||||Bit7|Transfer direction (0=OUT, 1=IN)|
|||||Bit6…4|Reserved (0)|
|||||Bit3…0|Endpointnumber|
|3|bmAttributes|1|02h|Attributes of the endpoint||
|||||Bit1…0|Transfer type|
|||||(00=Control, 01=Isochronous, 10=Bulk, 11=Interrupt)||
|4|wMaxPacketSize|2|0400h|Maximum packet size of this endpoint (0400h=1024Byte)||
|6|bInterval|1|00h|Pollinginterval(invalidfortheBulkand the Controlendpoints)||



## For HIGH-SPEED 

|Offset|Field|Size|Value|Description|Description|
|---|---|---|---|---|---|
|0|bLength|1|07h|Size of the descriptor||
|1|bDescriptorType|1|05h|Type of the descriptor (Endpoint descriptor)||
|2|bEndpointAddress|1|02h|Address ofthe endpoint||
|||||Bit7|Transfer direction (0=OUT, 1=IN)|
|||||Bit6…4|Reserved (0)|
|||||Bit3…0|Endpoint number|
|3|bmAttributes|1|02h|Attributes of the endpoint||
|||||Bit1…0|Transfertype|
|||||(00=Control, 01=Isochronous, 10=Bulk, 11=Interrupt)||
|4|wMaxPacketSize|2|0200h|Maximum packet size of this endpoint (0200h=512Byte)||
|6|bInterval|1|00h|Polling interval (invalid for the Bulk and the Control endpoints)||



## For FULL-SPEED 

|Offset|Field|Size|Value|Description|Description|
|---|---|---|---|---|---|
|0|bLength|1|07h|Size of the descriptor||
|1|bDescriptorType|1|05h|Type of the descriptor (Endpoint descriptor)||
|2|bEndpointAddress|1|02h|Address of the endpoint||
|||||Bit7|Transfer direction (0=OUT, 1=IN)|
|||||Bit6…4|Reserved (0)|
|||||Bit3…0|Endpoint number|
|3|bmAttributes|1|02h|Attributes ofthe endpoint||
|||||Bit1…0|Transfer type|
|||||(00=Control, 01=Isochronous, 10=Bulk, 11=Interrupt)||
|4|wMaxPacketSize|2|0040h|Maximumpacket size ofthis endpoint (0040h=64Byte)||
|6|bInterval|1|00h|Polling interval (invalid for the Bulk and the Control endpoints)||



Do Not Copy 

26/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.1.6.2 Bulk-In Endpoint** 

## For SUPER-SPEED 

|Offset|Field|Size|Value|Description|Description|
|---|---|---|---|---|---|
|0|bLength|1|07h|Size of the descriptor||
|1|bDescriptorType|1|05h|Type of the descriptor (Endpoint descriptor)||
|2|bEndpointAddress|1|81h|Address ofthe endpoint||
|||||Bit7|Transfer direction (0=OUT, 1=IN)|
|||||Bit6…4|Reserved (0)|
|||||Bit3…0|Endpoint number|
|3|bmAttributes|1|02h|Attributes of the endpoint||
|||||Bit1…0|Transfertype|
|||||(00 = Control、01 = Isochronous、10 = Bulk、11 = Interrupt)||
|4|wMaxPacketSize|2|0400h|Maximumpacket size ofthis endpoint (0400h=1024Byte)||
|6|bInterval|1|00h|Polling interval (invalid for the Bulk and the Control endpoints)||
|For HIGH-SPEED||||||
|Offset|Field|Size|Value|Description||
|0|bLength|1|07h|Size of the descriptor||
|1|bDescriptorType|1|05h|Type ofthe descriptor(Endpoint descriptor)||
|2|bEndpointAddress|1|81h|Address of the endpoint||
|||||Bit7|Transfer direction (0=OUT, 1=IN)|
|||||Bit6…4|Reserved (0)|
|||||Bit3…0|Endpoint number|
|3|bmAttributes|1|02h|Attributes ofthe endpoint||
|||||Bit1…0|Transfer type|
|||||(00 = Control、01 = Isochronous、10 = Bulk、11 = Interrupt)||
|4|wMaxPacketSize|2|0200h|Maximum packet size of this endpoint (0200h=512Byte)||
|6|bInterval|1|00h|Polling interval (invalid for the Bulk and the Control endpoints)||
|For FULL-SPEED||||||
|Offset|Field|Size|Value|Description||
|0|bLength|1|07h|Size ofthe descriptor||
|1|bDescriptorType|1|05h|Type of the descriptor (Endpoint descriptor)||
|2|bEndpointAddress|1|81h|Address of the endpoint||
|||||Bit7|Transferdirection(0=OUT,1=IN)|
|||||Bit6…4|Reserved (0)|
|||||Bit3…0|Endpointnumber|
|3|bmAttributes|1|02h|Attributes of the endpoint||
|||||Bit1…0|Transfer type|
|||||(00 = Control、01 = Isochronous、10 = Bulk、11 = Interrupt)||
|4|wMaxPacketSize|2|0040h|Maximum packet size of this endpoint (0040h=64Byte)||
|6|bInterval|1|00h|Pollinginterval(invalidfortheBulkand the Controlendpoints)||



Do Not Copy 

27/484 

**Confidential** 

**Nikon Corporation** 

## **Confidential** 

## **4.1.6.3 Interrupt Endpoint** 

## For SUPER-SPEED 

|Offset|Field|Size|Value|Description|Description|
|---|---|---|---|---|---|
|0|bLength|1|07h|Size of the descriptor||
|1|bDescriptorType|1|05h|Type of the descriptor (Endpoint descriptor)||
|2|bEndpointAddress|1|83h|Address ofthe endpoint||
|||||Bit7|Transfer direction (0=OUT, 1=IN)|
|||||Bit6…4|Reserved (0)|
|||||Bit3…0|Endpoint number|
|3|bmAttributes|1|03h|Attributes of the endpoint||
|||||Bit1…0|Transfertype|
|||||(00=Control, 01=Isochronous, 10=Bulk, 11=Interrupt)||
|4|wMaxPacketSize|2|0018h|Maximumpacket size ofthis endpoint (0018h=24Byte)||
|6|bInterval|1|0Ah|Polling interval (0Ah=10ms)||



## For HIGH-SPEED 

|Offset|Field|Size|Value|Description|Description|
|---|---|---|---|---|---|
|0|bLength|1|07h|Size of the descriptor||
|1|bDescriptorType|1|05h|Type ofthe descriptor(Endpoint descriptor)||
|2|bEndpointAddress|1|83h|Address of the endpoint||
|||||Bit7|Transfer direction (0=OUT, 1=IN)|
|||||Bit6…4|Reserved (0)|
|||||Bit3…0|Endpoint number|
|3|bmAttributes|1|03h|Attributes ofthe endpoint||
|||||Bit1…0|Transfer type|
|||||(00=Control, 01=Isochronous, 10=Bulk, 11=Interrupt)||
|4|wMaxPacketSize|2|0008h|Maximum packet size of this endpoint (0008h=8Byte)||
|6|bInterval|1|09h|Polling interval||
|For FULL-SPEED||||||
|Offset|Field|Size|Value|Description||
|0|bLength|1|07h|Size of the descriptor||
|1|bDescriptorType|1|05h|Type of the descriptor (Endpoint descriptor)||
|2|bEndpointAddress|1|83h|Address of the endpoint||
|||||Bit7|Transferdirection(0=OUT,1=IN)|
|||||Bit6…4|Reserved (0)|
|||||Bit3…0|Endpointnumber|
|3|bmAttributes|1|03h|Attributes of the endpoint||
|||||Bit1…0|Transfer type|
|||||(00=Control, 01 = Isochronous,10= Bulk,11 = Interrupt)||
|4|wMaxPacketSize|2|0008h|Maximum packet size of this endpoint (0008h=8Byte)||
|6|bInterval|1|09h|Pollinginterval||



Do Not Copy 

28/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.1.7 Super Speed Endpoint Companion Descriptor** 

## **4.1.7.1 Bulk-Out Endpoint** 

## For SUPER-SPEED 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|06h|Size ofthe descriptor|
|1|bDescriptorType|1|30h|Type of the descriptor (SuperSpeed Endpoint Companion<br>Descriptor)|
|2|bMaxBurst|1|0Fh|Maximum number of packets that can be transmitted and received<br>by burst transfer.<br>(Number of burst transfers -1) should be set.  The maximum value<br>is 15|
|3|bmAttributes|1|00h|Maximum number of streams for Bulk-Endpoint. 0 for no stream<br>definition.<br>In the case of an isochronous end point, the maximum number of<br>packets in the service interval.|
|4|wBytesPerInterval|2|0000h|Maximum number of bytes at which a fixed interval interrupt or<br>isochronous endpoint will transfer per service interval.|



## **4.1.7.2 Bulk-In Endpoint** 

## For SUPER-SPEED 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|06h|Size of the descriptor|
|1|bDescriptorType|1|30h|Type of the descriptor (SuperSpeed Endpoint Companion<br>Descriptor)|
|2|bMaxBurst|1|0Fh|Maximum number of packets that can be transmitted and received<br>by burst transfer.<br>(Number of burst transfers -1) should be set.  The maximum value<br>is 15|
|3|bmAttributes|1|00h|Maximum number of streams for Bulk-Endpoint. 0 for no stream<br>definition.<br>In the case of an isochronous end point, the maximum number of<br>packets in the service interval.|
|4|wBytesPerInterval|2|0000h|Maximum number of bytes at which a fixed interval interrupt or<br>isochronous endpoint will transfer per service interval.|



## **4.1.7.3 Interrupt Endpoint** 

## For SUPER-SPEED 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|06h|Size of the descriptor|
|1|bDescriptorType|1|30h|Type of the descriptor (SuperSpeed Endpoint Companion<br>Descriptor)|
|2|bMaxBurst|1|0Fh|Maximum number of packets that can be transmitted and received<br>by burst transfer.<br>(Number of burst transfers -1) should be set.  The maximum value<br>is 15|
|3|bmAttributes|1|00h|Maximum number of streams for Bulk-Endpoint. 0 for no stream<br>definition.<br>In the case of an isochronous end point, the maximum number of<br>packets in the service interval.|
|4|wBytesPerInterval|2|0018h|Maximum number of bytes at which a fixed interval interrupt or<br>isochronous endpointwilltransferperserviceinterval.|



Do Not Copy 

29/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.1.8 String Descriptor** 

## **4.1.8.1 Index1 (iManufacture)** 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|0Ch|Size of the descriptor|
|1|bDescriptorType|1|03h|Type of the descriptor (String descriptor)|
|2|bString|10|4E00h<br>4900h<br>4B00h<br>4F00h<br>4E00h|Unicode character string<br>“NIKON”|



## **4.1.8.2 Index2 (iProduct)** 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|1Ch|Size of the descriptor|
|1|bDescriptorType|1|03h|Type of the descriptor (String descriptor)|
|2|bString|30|4E00h<br>4900h<br>4B00h<br>4F00h<br>4E00h<br>2000h<br>4400h<br>5300h<br>4300h<br>2000h<br>5A00h<br>2000h<br>3600h<br>5F00h<br>3200h|Unicode character string<br>“NIKON DSC Z 6_2|



## **4.1.8.3 Index3 (iSerialNumber)** 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|42h|Size of the descriptor|
|1|bDescriptorType|1|03h|Type ofthe descriptor(String descriptor)|
|2|bString|64|XX00h<br>XX00h<br>XX00h<br>XX00h<br>XX00h<br>XX00h<br>XX00h<br>XX00h<br>XX00h<br>XX00h<br>XX00h<br>XX00h|Unicode character string<br>“XXXXXXXXXXXX”<br>Currently 0000h is set after the twelfth character.|



Do Not Copy 

30/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.1.9 BOS Descriptor** 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|05h|Size of the descriptor|
|1|bDescriptorType|1|0Fh|Type of the descriptor (BOS descriptor)|
|2|wTotalLength|2|0016h|Length of this descriptor and all of its sub descriptors|
|4|bString|1|02h|Thenumberofseparate device capability descriptorsintheBOS|



## **4.1.10 USB 2.0 Extension Descriptor** 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|07h|Size of the descriptor|
|1|bDescriptorType|1|10h|Type ofthe descriptor(DEVICECAPABILITYdescriptor)|
|2|bDevCapabilityType|1|02h|Capability type (USB 2.0 Extension)|
|3|bmAttributes|4|00000006h|Bit0 : Reserved<br>Bit1 : LPM (Link Power Management protocol)<br>Bit2 : BESL & Altermate HIRD definitions supported<br>Bit3 to Bit31 : Reserved|



## **4.1.11 Super Speed Device Capabilities Descriptor** 

|Offset|Field|Size|Value|Description|
|---|---|---|---|---|
|0|bLength|1|0Ah|Size of the descriptor|
|1|bDescriptorType|1|10h|Type of the descriptor (DEVICE CAPABILITY descriptor)|
|2|bDevCapabilityType|1|03h|Capability type (SUPERSPEED_USB)|
|3|bmAttributes|1|00h|Bit0 : Reserved<br>Bit1 : LTM Capable<br>Bit2toBit31 : Reserved|
|4|wSpeedsSupported|2|000Eh|Bit0 : Reserved<br>Bit1 : full-speed supported<br>Bit2 : high-speed supported<br>Bit3 : 5Gbs supported<br>Bit4 to Bit15 : Reserved|
|6|bFunctionalitySupport|1|01h||
|7|bU1DevExitLat|1|01h|U1 Device Exit Latency.<br>01h : Less than 1μs|
|8|wU1DevExitLat|2|0065h|U2 Device Exit Latency.<br>0065h : Less than 101μs|



Do Not Copy 

31/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **4.2 Class-Specific Descriptor** 

The camera has no class-specific descriptor. 

Do Not Copy 

32/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **5 Protocol** 

The camera supports the Bulk-Only Transport protocol.  In the Bulk-Only protocol, all transmission/reception of the command, data, and response are performed by the bulk transfer. When an asynchronous event is generated in the camera, the information is sent by the Interrupt transfer. 

The protocol processing is composed of three phases (command phase, data phase, and response phase).  All the commands, data, and responses are stored in the Generic Container Structure and transferred between the host and the camera.  The processing starts by sending the command (Bulk-Out transfer) from the host to the camera first (command phase).  Then the data is transmitted or received by the bulk transfer if the command needs the data transfer (data phase). The processing is completed when the device transmits the command response to the host (Bulk-In transfer) last (response phase).  The command and the response phases are always present. 

When sending the event to the host, the contents of the event to be sent are stored according to the asynchronous event interrupt data format and sent as the asynchronous event (Interrupt transfer). 

Do Not Copy 

33/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **5.1 Generic Container Structure** 

Each field data of the Generic Container Structure is transferred in order of the LSB first (little endian).  The Container Type and the contents of the Payload differ according to the phase difference. 

|Offset|Size|Field|Description|
|---|---|---|---|
|0|4|Container Length|The number of bytes in the unsigned integer of this container is<br>coded.<br>The still image capture device decides the container size by using<br>thisfield.|
|4|2|Container Type|This field shows the container type.<br>0: Not defined<br>1: Command block<br>2: Data block<br>3: Response block<br>4: Event block|
|6|2|Code|This field conforms to MTP Specification v1.0.  (OperationCode,<br>ResponseCode, or EventCode)<br>For the data block, the OperationCode of the command block is<br>used.|
|8|4|TransactionID|This is the number of the 32-bit unsigned integer created by the<br>host related to all the phases.<br>It starts with 0x00000001 and is incremented along with the<br>command block issue.  When the OperationCode is OpenSession,<br>0x00000000 is set and 0x00000001 is given by the next command<br>block.<br>When the number reaches the maximum value (0xFFFFFFFE), the<br>nextTransactionIDbecomes 0x00000001.|
|12|??|Payload|Differs depending on the phase.|



## **5.2 Asynchronous Event Interrupt Data Format** 

When an event is generated in the camera, the information is transferred to the host according to the following format.  Each field data is transferred in order of the LSB first (little endian). 

|Offset|Size|Field|Description|
|---|---|---|---|
|0|4|Container Length|The number of bytes in the unsigned integer of the length of this<br>container is coded.  The value is 0x00000010.|
|4|2|Container Type|Container Type=0x0004 (Event)|
|6|2|Code|EventCode|
|8|4|TransactionID|TransactionID=0xFFFFFFFF|
|12|??|Payload|Differs depending onthe event.|



Do Not Copy 

34/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **5.3 Phases** 

The communication between the camera and the host is composed of the three phases; command phase, data phase, and response phase.  The details of each phase are shown below. 

## **5.3.1 Command Phase** 

In the command phase, the host sends the Generic Container Structure of the command block to the camera.  The processing is started by sending the command block from the host in the command phase.  The camera performs the processing according to the OperationCode sent in the command block.  For the OperationCode and its processing, refer to subsection 6.2. The Generic Container Structure field data set in the command phase is shown below. 

|Offset|Size|Field|Description|
|---|---|---|---|
|0|4|Container Length|Indicates the length of this container.<br>Each code has its own container length.|
|4|2|Container Type|1: Command block|
|6|2|Code|Operation Code|
|8|4|TransactionID|This is the number given by the 32-bit unsigned integer created by<br>the host related to all the phases.  It starts with 0x00000001 and is<br>incremented by 1 along with the command block issue.  When the<br>OperationCode is OpenSession, 0x00000000 is set and<br>0x00000001 is given by the next command block.  When the<br>number reaches the maximum value of the field (0xFFFFFFFE),<br>the next TransactionID becomes 0x00000001.|
|12|4|Parameter 1|This field includes the operation parameter.  The format and the<br>meaning of the parameter differ depending on the OperationCode.|
|16|4|Parameter 2||
|20|4|Parameter3||



Do Not Copy 

35/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **5.3.2 Data Phase** 

The data phase is an optional phase used to transfer the data that is larger than what can fit in the data sets of the command or the response block.  According to the OperationCode specified by the command block, the data is transferred from the host to the camera, from the camera to the host, or not transferred at all.  For the OperationCode and the corresponding data contents, refer to subsection 6.2.  The Generic Container Structure field data set in the data phase is shown below. 

|Offset|Size|Field|Description|
|---|---|---|---|
|0|4|Container Length|Indicates the length of this container.<br>The container length differs depending on the size of the Payload.|
|4|2|Container Type|2: Data block|
|6|2|Code|The corresponding OperationCode sent in the command phase is<br>set.|
|8|4|TransactionID|This is the number given by the 32-bit unsigned integer created by<br>the host related to all the phases.  It starts with 0x00000001 and is<br>incremented by 1 along with the command block issue.  When the<br>OperationCode is OpenSession, 0x00000000 is set and<br>0x00000001 is given by the next command block.  When the<br>number reaches the maximum value of the field (0xFFFFFFFE),<br>the next TransactionID becomes 0x00000001.|
|12|??|Payload|The contents ofthisfield differdepending onthe OperationCode.|



Do Not Copy 

36/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **5.3.3 Response Phase** 

In the response phase, the Generic Container Structure of the response block is sent from the camera to the host in order to indicate whether the command sent in the command phase succeeds or fails. 

The contents of the response can be identified by the ResponseCode stored in the Code field. For the ResponseCode, refer to subsection 6.3. 

The Generic Container Structure field data set in the response phase is shown below. 

|Offset|Size|Field|Description|
|---|---|---|---|
|0|4|Container Length|Indicates the length of this container.<br>Each code has its own container length.|
|4|2|Container Type|3: Response block|
|6|2|Code|The ResponseCode is set in order to indicate whether the<br>processing corresponding to the OperationCode sent in the<br>command phase succeeds or fails.|
|8|4|TransactionID|This is the number given by the 32-bit unsigned integer created by<br>the host related to all the phases.  It starts with 0x00000001 and is<br>incremented by 1 along with the command block issue.  When the<br>OperationCode is OpenSession, 0x00000000 is set and<br>0x00000001 is given by the next command block.  When the<br>number reaches the maximum value of the field (0xFFFFFFFE),<br>the next TransactionID becomes 0x00000001.|
|12|4|Response<br>Parameter|This field includes the response parameter.  The format and the<br>meaning of the parameter differ depending on the OperationCode<br>and the ResponseCode.|



Do Not Copy 

37/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **5.4 Error Handling** 

If the following state is detected, the camera returns to the command phase status. 

|No.|Description|
|---|---|
|1|Bus reset|
|2|Reset recovery|



## **5.4.1 Command Block Reception Failure** 

When the command block reception fails and the reset recovery and the bus reset are not detected, the camera stalls the Bulk-In and the Bulk-Out endpoints and returns to the command phase status. 

## **5.4.2 Command Block Invalidity** 

When the following error is detected after the command block reception succeeds and the reset recovery and the bus reset are not detected, the camera stalls the Bulk-In and the Bulk-Out endpoints. 

|No.|Description|
|---|---|
|1|Container Type of Generic Container Structure is other than the command block.|



## **5.4.3 Command Execution Error** 

When the command execution error is detected after a valid command block is received, the phase is changed to the response phase and the response code corresponding to the error is set in the Code field of the Generic Container Structure and sent.  Stalling is not performed. 

Do Not Copy 

38/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6 Code** 

The codes supported by the camera are described. 

## **6.1 ObjectFormatCode** 

The ObjectFormatCode indicates the format of the objects in the card inserted in the camera (image file and script file) and the related objects (corresponding to the directories and the virtual association representing the relation between the images that conform to the DCF standards and the DCF objects in the camera).  The following table represents the ObjectFormatCodes supported by the camera. 

|ObjectFormatCode|Format|Description|
|---|---|---|
|0x3000|Undefined|NDF (dust reference image)<br>NEF (when MTP is not supported)<br>(In the definition of MTP Specification v1.0, it is defined as “Format<br>not defined”.)|
|0x3001|Association|Association<br>(Indicates the directories or the virtual association representing the<br>relation between the images that conform to the DCF standards<br>and the DCF objects.)|
|0x3002|Script|Script (only the virtual script file is the target)|
|0x3008<br>(Not supported)|WAV|AudioClip|
|0x3800|Unknown Image Object|NEF (when MTP is supported)|
|0x3801|EXIF/JPEG|JEIDA Standard|
|0x3808|JFIF|JPEG File Interchange Format (represents the thumbnail format.)|
|0x300D|MOV|Apple QuickTime Video Format (H.264/AVC)|
|0x380D|TIFF(RGB)|TagImageFileFormat|
|0xB982|MP4 Container|ISO 14496-1|



The ObjectFormatCode may be used as one of the parameters in the command phase. It is also used in the ObjectInfo data set. 

Do Not Copy 

39/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.1.1 Association Type** 

There are various Types in the Association defined by ObjectFormatCode.  Association is for representing the folders and the file system.  All the objects that belong to the Association correspond to the branches of the tree structure under the Association.  The associations to which the objects belong are specified in the ParentObject field of the ObjectInfo data set for each object. Type is specified in the AssociationType field of the ObjectInfo data set for the associations object. The Association Type used in the camera is shown below. 

|Association Code|Association Type|Description|
|---|---|---|
|0x0001|GenericFolder|Indicates the general directory.  For the camera, it indicates the DCF image<br>directory and DCF directory.|



An example of how the Association is used in the DCF file system for the camera is shown below. Note, however, that the directory name, the file name, and the ObjectHandle value may differ from the ObjectHandle that is actually used in the camera to simplify the explanation. 

|ObjectHandle|Description|ObjectFormatCode|ParentObject|
|---|---|---|---|
|0x00000001|¥DCIM folder|0x3001|0x00000000|
|0x00000002|¥DCIM¥100NIKON|0x3001|0x00000001|
|0x00000003|¥DCIM¥100NIKON¥DSC_0001.JPG|0x3801|0x00000002|
|0x00000004|¥DCIM¥100NIKON¥DSC_0002.NEF|0x3000|0x00000002|
|0x00000005|¥DCIM¥100NIKON¥DSC_0003.JPG|0x3801|0x00000002|
|0x00000006|¥DCIM¥100NIKON¥DSC_0003.NEF|0x3000|0x00000002|



**==> picture [282 x 133] intentionally omitted <==**

**----- Start of picture text -----**<br>
DCIM 100NIKON DSC_0001.JPG<br>(0x00000001) (0x00000002) (0x00000003)<br>DSC_0002.NEF<br>(0x00000004)<br>DSC_0003.JPG<br>(0x00000005)<br>DSC_0003.NEF<br>(0x00000006)<br>**----- End of picture text -----**<br>


Do Not Copy 

40/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2 Operation Code** 

The OperationCode is the command that is used by the host to request the operation of the camera in the command phase.  The OperationCode is sent as a part of the command block data set. 

The OperationCode is 2 bytes. 

Operation Codes that can be executed during live view/movie recording are shown below. 

The OperationCodes supported by the camera are shown below. 

|||`✓`: Can be executed,-: Cannot be executed|`✓`: Can be executed,-: Cannot be executed|`✓`: Can be executed,-: Cannot be executed|`✓`: Can be executed,-: Cannot be executed|
|---|---|---|---|---|---|
|Operation<br>Code|Description|Reference<br>item|Live view<br>photography|Movie live<br>view|During<br>movie<br>recording|
|0x1001|GetDeviceInfo|6.2.1.1|`✓`|`✓`|`✓`|
|0x1002|OpenSession|6.2.1.2|`✓`|`✓`|-|
|0x1003|CloseSession|6.2.1.3|`✓`|`✓`|`✓`|
|0x1004|GetStorageIDs|6.2.1.4|`✓`|`✓`|`✓`|
|0x1005|GetStorageInfo|6.2.1.5|`✓`|`✓`|`✓`|
|0x1006|GetNumObjects|6.2.1.6|`✓`|`✓`|`✓`|
|0x1007|GetObjectHandles|6.2.1.7|`✓`|`✓`|`✓`|
|0x1008|GetObjectInfo|6.2.1.8|`✓`|`✓`|-|
|0x1009|GetObject|6.2.1.9|`✓`|`✓`|-|
|0x100A|GetThumb|6.2.1.10|`✓`|`✓`|-|
|0x100B|DeleteObject|6.2.1.11|`✓`|`✓`|-|
|0x100C|SendObjectInfo|6.2.1.12|`✓`|`✓`|-|
|0x100D|SendObject|6.2.1.13|`✓`|`✓`|-|
|0x100E|InitiateCapture|6.2.1.14|`✓`|`✓`|-|
|0x100F|FormatStore|6.2.1.15|`✓`|`✓`|-|
|0x1014|GetDevicePropDesc|6.2.1.16|`✓`|`✓`|`✓`|
|0x1015|GetDevicePropValue|6.2.1.17|`✓`|`✓`|`✓`|
|0x1016|SetDevicePropValue|6.2.1.18|`✓`|`✓`|`✓`|
|0x101B|GetPartialObject|6.2.1.19|`✓`|`✓`|-|
|0x90C0|InitiateCaptureRecInSdram|6.2.2.19|`✓`|`✓`|`✓`|
|0x90C1|AfDrive|6.2.2.22|`✓`|`✓`|`✓`|
|0x90C2|ChangeCameraMode|6.2.2.5|`✓`|`✓`|-|
|0x90C3|DeleteImagesInSdram|6.2.2.17|`✓`|`✓`|-|
|0x90C4|GetLargeThumb|6.2.2.14|`✓`|`✓`|-|
|0x90C7|GetEvent|6.2.2.3|`✓`|`✓`|`✓`|
|0x90C8|DeviceReady|6.2.2.2|`✓`|`✓`|`✓`|
|0x90C9|SetPreWbData|6.2.2.42|`✓`|`✓`|-|
|0x90CA|GetVendorPropCodes|6.2.2.1|`✓`|`✓`|`✓`|
|0x90CB|AfAndCaptureRecInSdram|6.2.2.20|`✓`|`✓`|`✓`|
|0x90CC|GetPicCtrlData|6.2.2.43|`✓`|`✓`|`✓`|
|0x90CD|SetPicCtrlData|6.2.2.44|`✓`|`✓`|-|
|0x90CE|DeleteCustomPicCtrl|6.2.2.45|`✓`|`✓`|-|
|0x90CF|GetPicCtrlCapability|6.2.2.46|`✓`|`✓`|`✓`|
|0x9201|StartLiveView|6.2.2.26|`✓`|`✓`|`✓`|
|0x9202|EndLiveView|6.2.2.27|`✓`|`✓`|`✓`|
|0x9203|GetLiveViewImage|6.2.2.28|`✓`|`✓`|`✓`|
|0x9204|MfDrive|6.2.2.24|`✓`|`✓`|`✓`|
|0x9205|ChangeAfArea|6.2.2.31|`✓`|`✓`|`✓`|
|0x9206|AfDriveCancel|6.2.2.23|`✓`|`✓`|`✓`|
|0x9207|InitiateCaptureRecInMedia|6.2.2.18|`✓`|`✓`|`✓`|
|0x9209|GetVendorStorageIDs|6.2.2.9|`✓`|`✓`|`✓`|
|0x920A|StartMovieRecord|6.2.2.39|-|`✓`|-|
|0x920B|EndMovieRecord|6.2.2.40|`✓`|`✓`|`✓`|



Do Not Copy 

41/484 

**Confidential** 

## **Confidential** 

## **Nikon Corporation** 

|0x920C|TerminateCapture|6.2.2.21|`✓`|`✓`|-|
|---|---|---|---|---|---|
|0x920F|GetFhdPicture|6.2.2.15|`✓`|`✓`|-|
|0x9400|GetPartialObjectHighSpeed|6.2.2.13|`✓`|`✓`|-|
|0x9402|StartSpotWb|6.2.2.34|`-`|`✓`|-|
|0x9403|EndSpotWb|6.2.2.35|`✓`|`✓`|-|
|0x9404|ChangeSpotWbArea|6.2.2.36|`✓`|`✓`|-|
|0x9405|MeasureSpotWb|6.2.2.37|`✓`|`✓`|-|
|0x9406|EndSpotWbResultDisp|6.2.2.38|`✓`|`✓`|-|
|0x940C|CancelImagesInSdram|6.2.2.16|`✓`|`✓`|-|
|0x9414|GetSBHandles|6.2.2.49|`✓`|`✓`|`✓`|
|0x9415|GetSBAttrDesc|6.2.2.50|`✓`|`✓`|`✓`|
|0x9416|GetSBAttrValue|6.2.2.51|`✓`|`✓`|`✓`|
|0x9417|SetSBAttrValue|6.2.2.52|`✓`|`✓`|-|
|0x9418|GetSBGroupAttrDesc|6.2.2.53|`✓`|`✓`|`✓`|
|0x9419|GetSBGroupAttrValue|6.2.2.54|`✓`|`✓`|`✓`|
|0x941A|SetSBGroupAttrValue|6.2.2.55|`✓`|`✓`|-|
|0x941B|TestFlash|6.2.2.56|`✓`|`✓`|`✓`|
|0x941C|GetEventEx|6.2.2.4|`✓`|`✓`|`✓`|
|0x9420|SaveCameraSetting|6.2.2.8|`✓`|`✓`|-|
|0x9421|GetObjectSize|6.2.2.10|`✓`|`✓`|-|
|0x9422|ChangeMonitorOff|6.2.2.7|`✓`|`✓`|`✓`|
|0x9423|GetLiveViewCompressedSize|6.2.2.30|`✓`|`✓`|`✓`|
|0x9424|StartTracking|6.2.2.32|`✓`|`✓`|`✓`|
|0x9425|EndTracking|6.2.2.33|`✓`|`✓`|`✓`|
|0x9426|ChangeAELock|6.2.2.25|`✓`|`✓`|`✓`|
|0x9428|GetLiveViewImageEx|6.2.2.29|`✓`|`✓`|`✓`|
|0x9431|GetPartialObjectEx|6.2.2.12|`✓`|`✓`|-|
|0x9432|GetManualSettingLensData|6.2.2.48|`✓`|`✓`|`✓`|
|0x9433|InitiatePixelMapping|6.2.2.47|`✓`|`✓`|-|
|0x9434|GetObjectsMetaData|6.2.2.11|`✓`|`✓`|-|
|0x9435|ChangeApplicationMode|6.2.2.6|`✓`|`✓`|-|
|0x9436|ResetMenu|6.2.2.41|`✓`|`✓`|-|
|0x9801|GetObjectPropsSupported|6.2.2.57|`✓`|`✓`|`✓`|
|0x9802|GetObjectPropDesc|6.2.2.58|`✓`|`✓`|`✓`|
|0x9803|GetObjectPropValue|6.2.2.59|`✓`|`✓`|-|
|0x9805|GetObjectPropList|6.2.2.60|`✓`|`✓`|-|



Do Not Copy 

42/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1 Standard** 

## **6.2.1.1 GetDeviceInfo** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1001|
|Operation Parameter|Refer to Operation Parameter in this subsection.|
|Data|DeviceInfo data set|
|Data direction|From camera to host|
|Response Code|RefertoResponse Codeinthis subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode returns the information of the camera (DeviceInfo data set). The DeviceInfo data set includes information such as the camera version information and the codes supported by the camera. 

## ○ **Command Details** 

This operation is the only operation that may be issued inside or outside of a session. The contents of the DeviceInfo data set sent by the camera are shown in subsection 9.1. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Incomplete_Transfer|The data block transmission failed.|



Do Not Copy 

43/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.2 OpenSession** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1002|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode starts the logical connection (session) between the camera and the host. 

The SessionID is specified optionally by the host and retained during the session. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|SessionID|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Invalid_Parameter|The value of the parameter1 is 0x00000000.|
|Session_Already_Open|The session between the camera and the host has been already<br>started.|



Do Not Copy 

44/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.3 CloseSession** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1003|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode closes the logical connection (session) between the camera and the host. 

When this operation is performed, the operation being run is terminated.  Besides, the camera state changed after OpenSession returns to the default. 

|State|Contents of change|
|---|---|
|During shooting operation|Only the shooting operation currently being performed is<br>executed.  Forthe continuous shooting,itisnot continued.|
|During AF operation|The AF operation stops.|
|Duringremoteliveview|The cameraliveview is executed.|
|In the remote mode|The camera enters the PC camera mode.|
|The recording destination is<br>“SDRAM”or “Card and SDRAM”.|The recording destination is set to “Card”.|
|In the application mode|Set to OFF.|
|During forcibly monitor-off|Forcibly monitor-off is released.|
|During AE lock|AE lock is released (when the AE lock is not assigned in the<br>camera button).|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session isnot started.|
|Parameter_Not_Supported|An unsupported parameter is specified.|



Do Not Copy 

45/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.4 GetStorageIDs** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1004|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|StorageIDArray|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode returns a list of the currently valid StorageIDs. For the application mode, the StorageID with the card not inserted can be acquired by this command.  Therefore the valid StorageID can be known by using the GetVendorStorageIDs. 

## ○ **Command Details** 

The camera returns the StorageID of each slot. The StorageID of each slot takes the following values. 

|StorageID|Details|
|---|---|
|0x00010001|When the card is inserted in the slot1|
|0x00010000|Whenthe cardisnotinsertedinthe slot1|
||When the card in the slot1 is being formatted|
||When the battery is exhausted|
|0x00020001|When the card is inserted in the slot2|
|0x00020000|When the card is not inserted in the slot2|
||Whenthe cardinthe slot2 is beingformatted|
||When the battery is exhausted|



The format of the StorageIDArray that is sent by the camera is shown below. Each field data is stored in the little-endian format. 

|Field|Size (Byte)|Size (Byte)|Data|
|---|---|---|---|
|NumElement|4||0x00000002(Two elementsforthe array)|
|ArrayEntry1|4||StorageID (slot1)|
|ArrayEntry2|4||StorageID(slot2)|
|**Operation Parameter**||||
|Operation Parameter|||Details|
|Parameter1||None||
|Parameter2||None||
|Parameter3||None||
|**Response Code**||||
|Response Code|||Description|
|OK||Normal termination||
|Parameter_Not_Supported||Anunsupported parameter is specified.||
|Session_Not_Open||The session is not started.||
|Invalid_TransactionID||The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.||
|Incomplete_Transfer||The data block transmission failed.||



- **Operation Parameter** 

- **Response Code** 

Do Not Copy 

46/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.5 GetStorageInfo** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1005|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|StorageInfo|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the information of the card inserted in the camera. 

## ○ **Command Details** 

The camera returns the StorageInfo data set of the card specified by the StorageID. The StorageIDs supported by the camera are shown in subsection 6.2.1.4. The StorageInfo data set sent by the camera is described in subsection 9.2. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|StorageID|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_StorageID|The StorageID sent by the camera differs from the StorageID specified<br>by the host.|
|Store_Not_Available|The card is beinginitialized.|
||The card does not exist.|
||The batteryis exhausted.|



Do Not Copy 

47/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.6 GetNumObjects** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1006|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|NumObjects|



## ○ **Command Outline** 

The operation by this OperationCode obtains the number of objects that are present in the card. The number of objects recorded in the SDRAM is not included. 

## ○ **Command Details** 

If the new object is being recorded in the card when this command is received, the processing starts after the acquisition of all the data is completed. 

The camera returns the number of objects in the card specified by the StorageID.  In addition, Parameter2 and Parameter3, which are optional, can be combined. 

|Operation<br>Parameter|Value|Details|
|---|---|---|
|Parameter1|0xFFFFFFFF|Allthe cards should be the targets.|
||StorageID|The specified card should be the target.  Refer to subsection<br>6.2.1.4.|
|Parameter2<br>(Option)|0x00000000|Allthe objectformats should be the targets.|
||No value||
||0xFFFFFFFF|All the image formats in the card corresponding to the<br>specified StorageIDshould be the targets.|
||ObjectFormatCode|The specified object format should be the target.  Refer to<br>subsection 6.1.|
|Parameter3<br>(Option)|0x00000000|Allthe directories should be the targets.|
||No value||
||0xFFFFFFFF|The objects directly undertheroot should be the targets.|
||ObjectHandle|The objects directly under the specified directory should be<br>the targets.|



- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|StorageID|
|Parameter2|[ObjectFormatCode]|
|Parameter3|[ObjectHandle of the directory]|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Invalid_StorageID|The StorageID sent by the camera differs from the<br>StorageID specified by the host.|
|Invalid_Object_Handle|Foran invalid objecthandle|
|Store_Not_Available|The card is being initialized.|
||The card doesnot exist.|
||The batteryis exhausted.|
|Specification_By_Format_Unsupported|The specified ObjectFormatCode is not supported.|
|Invalid_Parent_Object|An ObjectHandle other than that indicating the directory in<br>the card was specified for ObjectHandle (Parameter3) of the<br>specified directory.|



Do Not Copy 

48/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

The specified directory does not exist. 

Do Not Copy 

49/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.7 GetObjectHandles** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1007|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ObjectHandleArray|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the handle of the object in the card.  The ObjectHandle of the object recorded in the SDRAM is not included. 

## ○ **Command Details** 

If the new object is being recorded in the card when this command is received, the processing starts after the acquisition of all the data is completed. 

The camera returns the ObjectHandle in the card specified by the StorageID.  In addition, Parameter2 and Parameter3, which are optional, can be combined. 

|Operation<br>Parameter|Value|Details|
|---|---|---|
|Parameter1|0xFFFFFFFF|Allthe cards should be the targets.|
||StorageID|The specified card should be the target.  Refer to subsection<br>6.2.1.4.|
|Parameter2<br>(Option)|0x00000000|Allthe objectformats should be the targets.|
||No value||
||0xFFFFFFFF|All the image formats in the card corresponding to the<br>specified StorageIDshould be the targets.|
||ObjectFormatCode|The specified object format should be the target.  Refer to<br>subsection 6.1.|
|Parameter3<br>(Option)|0x00000000|Allthe directories should be the targets.|
||No value||
||0xFFFFFFFF|The objects directly undertheroot should be the targets.|
||ObjectHandle|The objects directly under the specified directory should be<br>the targets.|



The format of the ObjectHandleArray that is sent by the camera is shown below. Each field data is stored in the little endian format. 

|Field|Size (Byte)|Data|
|---|---|---|
|NumElement|4|The element of the array is N (N indicates the number of<br>objects).|
|ArrayEntry [0]|4|ObjectHandle [0]|
|ArrayEntry [1]|4|ObjectHandle [1]|
|ArrayEntry [2]|4|ObjectHandle [2]|
|||---|
|ArrayEntry [N-1]|4|ObjectHandle [N-1]|



Do Not Copy 

50/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|StorageID||
|Parameter2|[ObjectFormatCode]||
|Parameter3|[ObjectHandle of the directory]||
|**Response Code**|||
|Response Code||Description|
|OK||Normal termination|
|Parameter_Not_Supported||An unsupported parameter is specified.|
|Session_Not_Open||The session is not started.|
|Invalid_TransactionID||The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer||The data block transmission failed.|
|Invalid_StorageID||The StorageID sent by the camera differs from the<br>StorageIDspecified by thehost.|
|Invalid_Object_Handle||For an invalid object handle|
|Store_Not_Available||The card is beinginitialized.|
|||The card does not exist.|
|||The battery is exhausted.|
|Specification_By_Format_Unsupported||The specified ObjectFormatCode is not supported.|
|Invalid_Parent_Object||An ObjectHandle other than that indicating the directory in<br>the card was specified for ObjectHandle (Parameter3) of the<br>specified directory.|
|||The specified directorydoes not exist.|



## ○ **Response Code** 

Do Not Copy 

51/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.8 GetObjectInfo** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1008|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ObjectInfo|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the information of the specified object (ObjectInfo). When a new object is added to the card and the host is informed of the addition of the object by the event, the host acquires the information of the object by this command. 

## ○ **Command Details** 

The camera sends the information of the object corresponding to the ObjectHandle specified in Parameter1. 

If the specified ObjectHandle is the data in the card, the camera returns the information of the object corresponding to the ObjectHandle. 

The ObjectHandle passed by ObjectAddedInSdram should be specified in order to acquire the information of the object in the SDRAM.  For the ObjectHandle passed by ObjectAddedInSdram, the image data information is sent to the host. 

The ObjectInfo data set sent in the data phase differs depending on the directory and the file types. 

The ObjectInfo data set of each object is shown in subsection 9.3. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|None|
|Parameter3|None|
|**Response Code**||
|Response Code|Description|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|
||An object in the SDRAM other than the ObjectHandle passed by<br>ObjectAddedInSdram is specified.|
|Store_Not_Available|The card is beinginitialized.|
||The card does not exist.|
||The battery is exhausted.|
|Access_Denied|The movie is playing.|



- **Response Code** 

Do Not Copy 

52/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.9 GetObject** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1009|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|DataObject|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the specified object (DataObject). 

## ○ **Command Details** 

The camera sends all the file data (DataObject) corresponding to the specified ObjectHandle to the host. 

If the specified ObjectHandle is the data in the card, the camera returns the object corresponding to the ObjectHandle. 

The ObjectHandle passed by ObjectAddedInSdram should be specified in order to acquire information of the object in the SDRAM.  For the ObjectHandle passed by ObjectAddedInSdram, the image data is sent to the host. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|
||The ObjectHandle of the directory (Association)is specified.|
||An object in the SDRAM other than the ObjectHandle passed by<br>ObjectAddedInSdram is specified.|
|Store_Not_Available|The card is beinginitialized.|
||The card does not exist.|
||The batteryis exhausted.|
|Access_Denied|Themovieis playing.|



Do Not Copy 

53/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.10 GetThumb** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x100A|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ThumbnailObject|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the thumbnail data of the specified image/movie object (ThumbnailObject). 

## ○ **Command Details** 

The camera sends the thumbnail data (ThumbnailObject) corresponding to the specified ObjectHandle to the host. 

If the specified ObjectHandle is the data in the card, the camera returns the thumbnail data corresponding to the ObjectHandle. 

The ObjectHandle passed by ObjectAddedInSdram should be specified in order to acquire the information of the object in the SDRAM.  For the ObjectHandle passed by ObjectAddedInSdram, the thumbnail data of the image or the movie data is sent to the host. 

ThumbnailObject is the thumbnail data of the object (file) specified in ObjectHandle.  The size of the ThumbnailObject is 160 x 120 of the small thumbnail size.  When the main image is in the JPEG format, the small thumbnail in the JPEG format is sent as it is.  When the main image is in the RAW format, the small thumbnail image recorded in the TIFF-RGB format is encoded to the JPEG format by the camera and then sent to the host.  However, when the thumbnail data is acquired from RAW in the SDRAM, the small thumbnail image recorded in the TIFF-RGB format is sent to the host as it is.  For the format of the RAW small thumbnail image, refer to the accompanying document “RAW Data Format for Digital Camera”. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|
||An object in the SDRAM other than the ObjectHandle passed by<br>ObjectAddedInSdram is specified.|
||WAV format object is specified.|
|No_Thumbnail_Present|The object corresponding to the specified ObjectHandle does not<br>have a thumbnail.|
|Store_Not_Available|The card is being initialized.|
||The card does not exist.|
||The batteryis exhausted.|
|Access_Denied|The movie isplaying.|



Do Not Copy 

54/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.11 DeleteObject** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x100B|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode deletes a specific object saved in the card or all the objects saved in the card.  The protected objects are not deleted. 

## ○ **Command Details** 

The protected objects are not deleted.  An object with an image format that is not supported by the camera is not deleted. 

The release is locked until the image deletion is completed. 

|Operation<br>Parameter|Value|Details|
|---|---|---|
|Parameter1|0xFFFFFFFF|All the objects in the card should be the targets.|
||ObjectHandle|The specified object should be the target.|
|Parameter2<br>(Option)|0x00000000|All the object formats should be the targets.|
||No value||
||ObjectFormatCode|The specified object format should be the target.<br>When 0xFFFFFFFF is specified in Parameter1, all the<br>objects that correspond to the specified object format are<br>deleted.|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|[ObjectFormatCode]|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle<br>doesnot exist.|
|Object_Write_Protect|The object corresponding to the specified ObjectHandle is<br>protected.|
|Partial_Deletion|When the deletion of two or more objects is specified, all<br>the objects are not deleted.|
|Store_Not_Available|The card is being initialized.|
||The card does not exist.|
||The battery is exhausted.|
|Store_Read_Only|The card including the specified image is protected.|
||Alltheinserted cards are protected.|
|Specification_By_Format_Unsupported|The specified ObjectFormatCode is not supported.|
|Device_Busy|The acquisition operation is being performed when the<br>command processingis started.|
|Invalid_Parameter|The ObjectFormatCode is specified with the ObjectHandle<br>set to a value other than 0xFFFFFFFF.|



Do Not Copy 

55/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.12 SendObjectInfo** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x100C|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ObjectInfo|
|Data direction|From host to camera|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|Refer to Response Parameter in this subsection.|



## ○ **Command Outline** 

The operation by this OperationCode sends the object information (ObjectInfo) from the host to the camera. 

## ○ **Command Details** 

The operation by this OperationCode is effective when the StorageID is 0x00000000 (the storage destination is not specified) and the Parent ObjectHandle is 0x00000000 or 0xFFFFFFFF. 

The camera retains the ObjectInfo received by this command until it receives the SendObject command to be sent from the host successively. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|[StorageID]|
|Parameter2|[(Parent) ObjectHandle]|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Incomplete_Transfer|The data block reception failed.|
|Invalid_StorageID|The StorageID is a value other than 0x00000000.|
|Invalid_ObjectFormatCode|The ObjectFormat field of the received ObjectInfo is set to a value other<br>than 0x3002 (Script).|
|Store_Full|The object cannot be received with the size of the buffer prepared by<br>the camera (32768Byte).|
|Access_Denied|A StorageID of the card is specified.|
|Specification_of_<br>Destination_Unsupported|The (Parent) ObjectHandle is a value other than 0x00000000 or<br>0xFFFFFFFF.|



- **Response Parameter** 

|ResponseParameter|Description|
|---|---|
|Parameter1|StorageID [0x00000000]|
|Parameter2|Parent ObjectHandle [0x00000000]|
|Parameter3|Any ObjectHandle|



Do Not Copy 

56/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.13 SendObject** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x100D|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|DataObject|
|Data direction|From host to camera|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode sends the object from the host to the camera. 

## ○ **Command Details** 

The camera records the ObjectData based on the information of the ObjectInfo received in advance.  The recording destination is not a card but a virtual recording medium (SDRAM).  The camera deletes the ObjectInfo data received in advance when receiving this command and completing the ObjectData reception. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block reception failed.|
|No_Valid_ObjectInfo|This command is received before the SendObjectInfo command is<br>accepted.|



Do Not Copy 

57/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.14 InitiateCapture** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x100E|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|
|Event Code|RefertoEvent Codeinthis subsection.|



## ○ **Command Outline** 

The operation by this OperationCode starts the camera acquiring one or more new objects (release operation of the camera) according to the current setting.  The acquired objects (image data) are always recorded in the card independently of the recording destination property. 

## ○ **Command Details** 

The camera starts the release operation when receiving this command.  The camera returns OK after starting the release operation.  If the AF is required, the camera starts the release operation after finishing the AF. (This command is an activation command, so returns the response code before the release operation is completed.) 

The camera starts acquiring one or more new objects (release operation of the camera) according to the current setting.  The acquisition of the new object is performed asynchronously. 

Whether the AF is operated when the release is started depends on the setting of the focus-mode selector. 

Refer to Command Release Operation (subsection 11.7) for the details of the command release operation. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|[StorageID]||
||0x00000000|The recording destination specified in the camera.|
||StorageID|The specified recording destination.|
|Parameter2|[ObjectFormatCode]||
||0x00000000|The image quality mode set in the camera.|
||ObjectFormatCode|Theimage qualitymode according to theformat.|
|Parameter3|None||



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|General_Error|An error is generated in the camera body when the command<br>processing is started.|
||All of the following conditions are satisfied, andthe AF operation is not<br>focused.<br>-The AF operation mode is set to [Focus priority].<br>- The LiveViewSelector property (subsection 6.5.12.8) is set to [Live<br>viewphotography].|
||The aperture value is“F--”.|
|Invalid_StorageID|The StorageID sent by the camera differs from the StorageID<br>specified by the host.|
|Invalid_ObjectFormatCode|The format of the ObjectFormatCode is not supported by the camera.|
|Store_Full|Thefree areafor recordingisnot providedinthe card.|
|Store_Not_Available|The card is beinginitialized.|
||The card does not exist.|



Do Not Copy 

58/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

|**idential**|**Nikon Corporati**|
|---|---|
||The battery is exhausted.|
|Store_Read_Only|Alltheinserted cards are protected.|
|Device_Busy|The acquisition operation is being performed when the command<br>processing is started.|
||The shutter-release button is beingfullypressed.|
|Access_Denied|Whenaretractablelensismounted, thelensisretracting.|
||STM lens is being initialized.|
||The MovieLogOutput property (subsection 6.5.7.27) is [On].|
||Shooting cannot be performed depending onthe state of the camera<br>other than the above factors.|



## ○ **Event Code** 

|Event Code|Details|
|---|---|
|ObjectAdded|A new object is recorded in the card.|
|StoreFull|Thefree areafor recordingisnot providedinthe card.|
|CaptureComplete|The acquisition operation of the new object is completed.|



Do Not Copy 

59/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.15 FormatStore** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x100F|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode formats the card inserted in the camera. 

## ○ **Command Details** 

The camera formats the card specified by the StorageID. 

The StorageIDs supported by the camera are shown in subsection 6.2.1.4. The FilesystemFormat parameter shown in Parameter2 is optional.  However, setting of only 0x0003 indicating the DCF is permitted. 

- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|StorageID|
|Parameter2|[FilesystemFormat]|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_StorageID|The StorageID sent by the camera differs from the StorageID<br>specified by thehost.|
|Store_Not_Available|The card is being initialized.|
||The card doesnot exist.|
||The battery is exhausted.|
|Store_Read_Only|The specified card is protected.|
|Device_Busy|The acquisition operation is being performed when the command<br>processing is started.|
|Invalid_Parameter|Parameter2 isneither0x00000000nor0x00000003.|



Do Not Copy 

60/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.16 GetDevicePropDesc** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1014|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|DevicePropDesc data set|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode returns the DevicePropDesc data set corresponding to the specified DevicePropCode. 

## ○ **Command Details** 

For the supported DevicePropCode, refer to subsection 6.5. For the DevicePropDesc, refer to subsection 9.4. 

- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|DevicePropCode|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|DeviceProp_Not_Supported|The specified DevicePropCode is not supported.|



Do Not Copy 

61/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.17 GetDevicePropValue** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1015|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|DevicePropValue|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode returns the current value corresponding to the specified DevicePropCode. 

## ○ **Command Details** 

For the supported DevicePropCode and the details of the DevicePropValue, refer to subsection 6.5. 

- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|DevicePropCode|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|DeviceProp_Not_Supported|The specified DevicePropCode is not supported.|



Do Not Copy 

62/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.18 SetDevicePropValue** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x1016|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|DevicePropValue|
|Data direction|From host to camera|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|
|Event Code|RefertoEvent Codeinthis subsection.|



## ○ **Command Outline** 

The operation by this OperationCode sets the DevicePropValue corresponding to the specified DevicePropCode to the camera. 

## ○ **Command Details** 

For the supported DevicePropCode and the details of the DevicePropValue, refer to subsection 6.5. 

- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|DevicePropCode|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block reception failed.|
|DeviceProp_Not_Supported|The specifiedDevicePropCodeisnot supported.|
|Access_Denied|An operation is denied depending on the status of the camera.|
||The specified DevicePropCode is not permitted for setting.|
|Device_Busy|The acquisition operation is being performed when the command<br>processing is started, or the AF is being operated.|
|Invalid_DeviceProp_Format|The size or the format of the DevicePropDesc data set is not<br>appropriate.|
|Invalid_DeviceProp_Value|The specified DevicePropValue is not supported.|



- **Event Code** 

|Event Code|Details|
|---|---|
|StorageInfoChanged|The settings of the ImageSize and the CompressionSetting properties<br>are changed.|



Do Not Copy 

63/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.1.19 GetPartialObject** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x101B|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|DataObject|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|The number of bytes actually sent|



## ○ **Command Outline** 

The operation by this OperationCode is the same as that of GetObject. 

However, the offset and the number of bytes to be acquired can be specified and the object (DataObject) can be acquired partially. 

## ○ **Command Details** 

The camera sends the file data (DataObject) of the specified size corresponding to the specified ObjectHandle to the host.  When the specified ObjectHandle is the data in the card, the camera returns the object corresponding to the ObjectHandle. 

The ObjectHandle passed by ObjectAddedInSdram should be specified in order to acquire the information of the object in the SDRAM. 

For the DataObject, which is the data to be sent, the file data corresponding to the specified ObjectHandle for MaxSize starting from the position set by the offset is sent to the host.  In the case of “(File size - Offset) < MaxSize”, the data of “(File size - Offset)”, not MaxSize, is sent to the host. The sent number of bytes is stored in ResponseParameter and sent to the host. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|Offset (Byte)|
|Parameter3|MaxSize(Byte）|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session isnot started.|
|Incomplete_Transfer|The data block transmission failed.|
||The size of the object corresponding to the specified ObjectHandle is 4<br>GB or more.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|
||The ObjectHandle of the directory (Association) is specified.|
||An object in the SDRAM other than the ObjectHandle passed by<br>ObjectAddedInSdram is specified.|
|Access_Denied|The movie is playing.|



Do Not Copy 

64/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2 Vendor** 

## **6.2.2.1 GetVendorPropCodes** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90CA|
|Operation Parameter|Refer to Operation Parameter in this subsection.|
|Data|DevicePropCodeArray|
|Data direction|From camera to host|
|Response Code|RefertoResponse Codeinthis subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires an array of codes of the vendor property supported by the camera. 

## ○ **Command Details** 

The format of DevicePropCodeArray sent by the camera is shown below. Each field data is stored in the little endian format. 

|Field|Size (Byte)|Data|
|---|---|---|
|NumElement|4|The element of the array is N (N indicates the<br>numberofobjects).|
|ArrayEntry [0]|2|DevicePropCode [0]|
|ArrayEntry [1]|2|DevicePropCode [1]|
|ArrayEntry [2]|2|DevicePropCode [2]|
|・・・|||
|ArrayEntry [N - 1]|2|DevicePropCode [N - 1]|



- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data blocktransmission failed.|



Do Not Copy 

65/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.2 DeviceReady** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90C8|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode checks the action by the activation-type command. 

## ○ **Command Details** 

This command is issued after issuing the following activation-type commands in order to check the operation. 

|Activation-type commands|Reference|
|---|---|
|InitiateCapture|6.2.1.14|
|InitiateCaptureRecInMedia|6.2.2.18|
|InitiateCaptureRecInSdram|6.2.2.19|
|AfAndCaptureRecInSdram|6.2.2.20|
|AfDrive|6.2.2.22|
|MfDrive|6.2.2.24|
|StartLiveView|6.2.2.26|



This command should be issued repeatedly until the operation of the activation-type command is completed. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Device_Busy|The operation of the activation-type command is not finished.|
|Out_of_Focus|TheAFoperationby the commandisinthenon-focused status.|
|Wb_Preset_Error|The preset measurement release failed.|
|MfDrive_Step_End|The MF driving reaches the end of steps.|
|MfDrive_Step_ Insufficiency|The driving amount is insufficient.|
|Bulb_Release_Busy|The bulb shooting is being performed.|
|Silent_Release_Busy|During the silent photography (Only models that support the silent<br>photography).|
|MovieFrame_Release_Busy|The frames for the movie recording are being saved.|



Do Not Copy 

66/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.3 GetEvent** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90C7|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|Event array|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode sends the event retained in the camera to the host. 

## ○ **Command Details** 

This OperationCode is a command for compatibility with the GetEventEx command (subsection 6.2.2.4) and has the following restriction. The GetEventEx command (subsection 6.2.2.4) should be used for this camera. 

This command cannot handle the events that have two or more parameters. 

The format of the event array to be sent by the camera is shown below. 

|Offset|Value|Name|Description|
|---|---|---|---|
|0|N|EventCount|The number of events|
|2|EventCode|EventCode [0]|The oldest event|
|4||EventParameter [0]|Parameter attaching to the oldest event|
|8|EventCode|EventCode [1]|The second oldest event|
|10||EventParameter [1]|Parameter attaching to the second<br>oldest event|
|||・・・||
|6 x (N–1)+2|EventCode|EventCode [N-1]|The newest event|
|6 x (N – 1) + 4||EventParameter [N - 1]|Parameter attaching to the newest<br>event|



If there is no event to be sent, the EventCount value is set to 0 and sent to the host. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data blocktransmission failed.|



Do Not Copy 

67/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.4 GetEventEx** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x941C|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|Event array|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode sends the event retained in the camera to the host. 

## ○ **Command Details** 

The camera sends all the events saved in the event queue buffer prepared for the GetEventEx command. 

After sending the event, the event stored in the queue buffer is deleted. 

|The format of the event array to be sent by the camera is shown below.<br>Field<br>DataSize<br>DataType<br>Description<br>NumberOfElements<br>4<br>UINT32<br>The number of events in the list.<br>Element1 Event Code<br>2<br>UINT16<br>Event Codeforelement1.<br>Element1 NumParameters<br>2<br>UINT16<br>Number of parameters for element1.<br>Element1 Parameter1<br>4<br>UINT32<br>Parameter1 for element1.<br>Element1 Parameter2<br>4<br>UINT32<br>Parameter2 for element1.<br>…<br>Element1 ParameterN<br>4<br>UINT32<br>Parameter N forelement1.<br>…<br>ElementN Event Code<br>2<br>UINT16<br>Event Code for element N.<br>ElementN NumParameters<br>2<br>UINT16<br>Number of parameters for element N.<br>ElementN Parameter1<br>4<br>UINT32<br>Parameter1 for element N.<br>ElementN Parameter2<br>4<br>UINT32<br>Parameter2 forelementN.<br>…<br>ElementN ParameterN<br>4<br>UINT32<br>Parameter N forelementN.|The format of the event array to be sent by the camera is shown below.<br>Field<br>DataSize<br>DataType<br>Description<br>NumberOfElements<br>4<br>UINT32<br>The number of events in the list.<br>Element1 Event Code<br>2<br>UINT16<br>Event Codeforelement1.<br>Element1 NumParameters<br>2<br>UINT16<br>Number of parameters for element1.<br>Element1 Parameter1<br>4<br>UINT32<br>Parameter1 for element1.<br>Element1 Parameter2<br>4<br>UINT32<br>Parameter2 for element1.<br>…<br>Element1 ParameterN<br>4<br>UINT32<br>Parameter N forelement1.<br>…<br>ElementN Event Code<br>2<br>UINT16<br>Event Code for element N.<br>ElementN NumParameters<br>2<br>UINT16<br>Number of parameters for element N.<br>ElementN Parameter1<br>4<br>UINT32<br>Parameter1 for element N.<br>ElementN Parameter2<br>4<br>UINT32<br>Parameter2 forelementN.<br>…<br>ElementN ParameterN<br>4<br>UINT32<br>Parameter N forelementN.|The format of the event array to be sent by the camera is shown below.<br>Field<br>DataSize<br>DataType<br>Description<br>NumberOfElements<br>4<br>UINT32<br>The number of events in the list.<br>Element1 Event Code<br>2<br>UINT16<br>Event Codeforelement1.<br>Element1 NumParameters<br>2<br>UINT16<br>Number of parameters for element1.<br>Element1 Parameter1<br>4<br>UINT32<br>Parameter1 for element1.<br>Element1 Parameter2<br>4<br>UINT32<br>Parameter2 for element1.<br>…<br>Element1 ParameterN<br>4<br>UINT32<br>Parameter N forelement1.<br>…<br>ElementN Event Code<br>2<br>UINT16<br>Event Code for element N.<br>ElementN NumParameters<br>2<br>UINT16<br>Number of parameters for element N.<br>ElementN Parameter1<br>4<br>UINT32<br>Parameter1 for element N.<br>ElementN Parameter2<br>4<br>UINT32<br>Parameter2 forelementN.<br>…<br>ElementN ParameterN<br>4<br>UINT32<br>Parameter N forelementN.|The format of the event array to be sent by the camera is shown below.<br>Field<br>DataSize<br>DataType<br>Description<br>NumberOfElements<br>4<br>UINT32<br>The number of events in the list.<br>Element1 Event Code<br>2<br>UINT16<br>Event Codeforelement1.<br>Element1 NumParameters<br>2<br>UINT16<br>Number of parameters for element1.<br>Element1 Parameter1<br>4<br>UINT32<br>Parameter1 for element1.<br>Element1 Parameter2<br>4<br>UINT32<br>Parameter2 for element1.<br>…<br>Element1 ParameterN<br>4<br>UINT32<br>Parameter N forelement1.<br>…<br>ElementN Event Code<br>2<br>UINT16<br>Event Code for element N.<br>ElementN NumParameters<br>2<br>UINT16<br>Number of parameters for element N.<br>ElementN Parameter1<br>4<br>UINT32<br>Parameter1 for element N.<br>ElementN Parameter2<br>4<br>UINT32<br>Parameter2 forelementN.<br>…<br>ElementN ParameterN<br>4<br>UINT32<br>Parameter N forelementN.|The format of the event array to be sent by the camera is shown below.<br>Field<br>DataSize<br>DataType<br>Description<br>NumberOfElements<br>4<br>UINT32<br>The number of events in the list.<br>Element1 Event Code<br>2<br>UINT16<br>Event Codeforelement1.<br>Element1 NumParameters<br>2<br>UINT16<br>Number of parameters for element1.<br>Element1 Parameter1<br>4<br>UINT32<br>Parameter1 for element1.<br>Element1 Parameter2<br>4<br>UINT32<br>Parameter2 for element1.<br>…<br>Element1 ParameterN<br>4<br>UINT32<br>Parameter N forelement1.<br>…<br>ElementN Event Code<br>2<br>UINT16<br>Event Code for element N.<br>ElementN NumParameters<br>2<br>UINT16<br>Number of parameters for element N.<br>ElementN Parameter1<br>4<br>UINT32<br>Parameter1 for element N.<br>ElementN Parameter2<br>4<br>UINT32<br>Parameter2 forelementN.<br>…<br>ElementN ParameterN<br>4<br>UINT32<br>Parameter N forelementN.|
|---|---|---|---|---|
||Field|DataSize|DataType|Description|
||NumberOfElements|4|UINT32|The number of events in the list.|
||Element1 Event Code|2|UINT16|Event Codeforelement1.|
||Element1 NumParameters|2|UINT16|Number of parameters for element1.|
||Element1 Parameter1|4|UINT32|Parameter1 for element1.|
||Element1 Parameter2|4|UINT32|Parameter2 for element1.|
||||…||
||Element1 ParameterN|4|UINT32|Parameter N forelement1.|
||||…||
||ElementN Event Code|2|UINT16|Event Code for element N.|
||ElementN NumParameters|2|UINT16|Number of parameters for element N.|
||ElementN Parameter1|4|UINT32|Parameter1 for element N.|
||ElementN Parameter2|4|UINT32|Parameter2 forelementN.|
||||…||
||ElementN ParameterN|4|UINT32|Parameter N forelementN.|



If there is no event to be sent, the EventCount value is set to 0 and sent to the host. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data blocktransmission failed.|



Do Not Copy 

68/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.5 ChangeCameraMode** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90C2|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode switches between the PC camera mode and the remote mode. 

## ○ **Command Details** 

The camera is set to the mode specified by the ModeValue. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|ModeValue||
||0|Sets to the PC camera mode.|
||1|Sets to the remote mode.|
|Parameter2|None||
|Parameter3|None||



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|The specified value of ModeValue is out of the range.|
|Change_CameraMode_Failed|Duringshootingoperation.|
||Duringthe AF operation.|
||Duringcleaningimage sensor.|
||During pixel mappingoperation.|



Do Not Copy 

69/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.6 ChangeApplicationMode** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9435|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode switches the application mode. 

## ○ **Command Details** 

Refer to subsection 2.4 for the application mode. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|Mode||
||0|Application mode OFF|
||1|Application mode ON|
|Parameter2|None||
|Parameter3|None||



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|The specified value of ModeValue is out of the range.|



Do Not Copy 

70/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.7 ChangeMonitorOff** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9422|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode changes the monitor forced off state of the camera. 

## ○ **Command Details** 

When the camera receives this command, it switches the monitor forced off state. 

If “Forced light off” is specified for MonitorOffStatus of Parameter1 while the monitor is on, the monitor turns off. 

If "Cancel forced light off" is specified while the monitor is off, the monitor turns on or off according to the camera status. 

Monitors targeted by this command are as follows. 

- Main monitor (Playback monitor) 

The response of the normal end indicates that the request to switch the monitor off state has been received, completion of turning on / off the monitor is not guaranteed. 

Refer to MonitorOffStatus property (subsection 6.5.7.19) for the monitor forced off state. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|MonitorOffStatus||
||0|Cancel forced light off.|
||1|Forced light off.|
|Parameter2|None||
|Parameter3|None||



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|The specifiedvalueis out oftherange.|
|Device_Busy|The acquisition operation is being performed when the command<br>processing is started.|
|Access_Denied|The batteryis exhausted|
|Hardware_Error|When the command processing is started, some error is generated in<br>the camera body.|



Do Not Copy 

71/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.8 SaveCameraSetting** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9420|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode saves the camera setting values.  This is the same operation as that of saving the camera setting values when the power switch is turned off. 

## ○ **Command Details** 

The camera setting values are stored in the non-volatile area.  If this operation is not completed in the case that the power supply is interrupted in saving the setting values, the operation of the camera is not guaranteed after that. 

After responding to this command, do not execute any command (other than CloseSession) or do not operate the camera other than power OFF. 

## ○ **Operation Parameter** 

|Operation Parameter||Details|
|---|---|---|
|Parameter1|None||
|Parameter2|None||
|Parameter3|None||
|**Response Code**|||
|Response Code||Description|
|OK||Normal termination|
|Parameter_Not_Supported||An unsupported parameter is specified.|
|Session_Not_Open||The session is not started.|
|Invalid_TransactionID||The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Device_Busy||The shooting operation is being performed.|
|Access_Denied||During thePC cameramode.|
|||The camera cannot save the setting values.|



- **Response Code** 

Do Not Copy 

72/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.9 GetVendorStorageIDs** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9209|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|StorageIDArray|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode returns a list of the currently valid StorageIDs. For the application mode, the StorageID with the card not inserted can be acquired by GetStorageIDs.  Therefore the valid StorageID can be known by using this operation. 

## ○ **Command Details** 

The camera returns the StorageID of each slot. 

The StorageID of each slot takes the following values. 

|StorageID|Details|
|---|---|
|0x00010001|When the card is inserted in the slot1|
|0x00010000|When the card is not inserted in the slot1|
||Whenthe cardinthe slot1 is beingformatted|
||When the battery is exhausted|
|0x00020001|When the card is inserted in the slot2|
|0x00020000|When the card is not inserted in the slot2|
||When the card in the slot2 is being formatted|
||Whenthe batteryis exhausted|



The format of the StorageIDArray that is sent by the camera is shown below. Each field data is stored in the little endian format. 

|Field|Size (Byte)|Data|
|---|---|---|
|NumElement|4|0x00000002 (Two elements for the array)|
|ArrayEntry1|4|StorageID(slot1)|
|ArrayEntry2|4|StorageID (slot2)|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|



Do Not Copy 

73/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.10 GetObjectSize** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9421|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ObjectSize|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the size of the specified object. 

## ○ **Command Details** 

When the value of the ObjectCompressedSize returned by GetObjectInfo command is 0xFFFFFFFF, the correct size of the object can be obtained by this operation code. 

The ObjectSize transmitted by the camera is 8 bytes of data. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|
||An object in the SDRAM other than the ObjectHandle passed by<br>ObjectAddedInSdram is specified.|
|Store_Not_Available|The card is beinginitialized.|
||The card does not exist.|
||The battery is exhausted.|
|Access_Denied|The movie is playing.|



Do Not Copy 

74/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.11 GetObjectsMetaData** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9434|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ObjectMetaData Dataset|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the handle and the metadata of the object in the card.  The ObjectHandle of the object recorded in the SDRAM is not included. 

## ○ **Command Details** 

If the new object is being recorded in the card when this command is received, the processing starts after the acquisition of all the data is completed. 

The camera returns the ObjectHandle and the metadata in the card specified by the StorageID. In addition, Parameter2 and Parameter3, which are optional, can be combined. 

|Operation<br>Parameter|Value|Details|
|---|---|---|
|Parameter1|0xFFFFFFFF|Allthe cards should be the targets.|
||StorageID|The specified object should be the target.|
|Parameter2<br>(Option)|0x00000000|All the object formats should be the targets.|
||No value||
||0xFFFFFFFF|All the image formats in the card corresponding to the<br>specified StorageID should be the targets.|
||ObjectFormatCode|The specified object format should be the target.|
|Parameter3<br>(Option)|0x00000000|All the directories should be the targets. (NOTE1)|
||Novalue||
||ObjectHandle|The objects directly under the specified directory should be<br>the targets.|



NOTE1: Since the processing time increases in proportion to the number of objects, if all directories are specified with a large number of objects, it may take time to execute. 

The format of the ObjectMetaData Dataset sent by the camera is shown below. 

|||ObjectMetaData Dataset|ObjectMetaData Dataset||
|---|---|---|---|---|
|Field||Size(Byte)|DataType|Description|
|Version||4|UINT32|Dataset version<br>Version 1.00|
|NumElement||4|UINT32|Numberof metadata|
|ObjectMetaData[0]||16|-|Metadata 1|
||ObjectHandle|4|UINT32|Objecthandle|
||ObjectAttribute|4|UINT32|Bit2 and after: Reserved<br>Bit1: Protected<br>Bit0: Rating|
||Reserved|1|UINT8|-|
||ModificationDate|1|UINT8|Modification date: Second|
|||1|UINT8|Modificationdate: Minute|
|||1|UINT8|Modification date: Hour|
|||1|UINT8|Modification date: Day|
|||1|UINT8|Modification date: Month|
|||2|UINT16|Modification date: Year|
|ObjectMetaData[1]||16|-|Metadata2|
||||・・・||
|ObjectMetaData[N - 1]||16|-|MetadataN|



Do Not Copy 

75/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|StorageID||
|Parameter2|[ObjectFormatCode]||
|Parameter3|[ObjectHandle ofdirectory]||
|**Response Code**|||
|Response Code||Description|
|OK||Normaltermination|
|Parameter_Not_Supported||An unsupported parameter is specified.|
|Session_Not_Open||The session is not started.|
|Invalid_TransactionID||The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_StorageID||The StorageID sent by the camera differs from the<br>StorageID specified by the host.|
|Invalid_Object_Handle||For an invalid object handle|
|Store_Not_Available||The card is beinginitialized.|
|||The card does not exist.|
|||The battery is exhausted.|
|Specification_By_Format_Unsupported||The specified ObjectFormatCode is not supported.|
|Invalid_Parent_Object||An ObjectHandle other than that indicating the directory in<br>the card was specified for ObjectHandle (Parameter3) of the<br>specified directory.|
|||The specified directory doesnot exist.|
|Device_Busy||The management file is not ready.|



## ○ **Response Code** 

Do Not Copy 

76/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.12 GetPartialObjectEx** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9431|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|DataObject|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|Refer to Response Parameter in this subsection.|



## ○ **Command Outline** 

The operation by this OperationCode is an extension of GetPartialObject (subsection 6.2.1.19). 

## ○ **Command Details** 

The Offset, MaxSize and actual number of bytes sent (Response Parameter) are expanded. Objects up to the size represented by 8 Bytes can be obtained. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|Offset (Lower 4Byte)|
|Parameter3|Offset (Upper 4Byte)|
|Parameter4|MaxSize (Lower 4Byte)|
|Parameter5|MaxSize (Upper 4Byte)|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|
||The ObjectHandle of the directory (Association) is specified.|
||An object in the SDRAM other than the ObjectHandle passed by<br>ObjectAddedInSdram is specified.|
|Access_Denied|Themovieis playing.|



## ○ **Response Parameter** 

|Response Parameter|Description|
|---|---|
|Parameter1|Actual numberofbytes sent (Lower 4Byte)|
|Parameter2|Actual number of bytes sent(Upper 4Byte)|



Do Not Copy 

77/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.13 GetPartialObjectHighSpeed** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9400|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|DataObject|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|Refer to Response Parameter in this subsection.|



## ○ **Command Outline** 

The operation by this OperationCode transfers the file data (DataObject) of the specified size corresponding to the specified ObjectHandle (parameter1) from the camera to the host. 

This command is suited to transfer large-size file because the time for the camera to read the data from the card is shorter than that of the GetPartialObject command (subsection 6.2.1.19). 

## ○ **Command Details** 

The maximum size of the data transferred by this command is the size of the file specified by the ObjectHandle (parameter1).  The data size can be checked by the GetObjectInfo command (subsection 6.2.1.8). 

The following must be satisfied to use this command. 

- `・` Turn on application mode by using ChangeApplicationMode command (subsection 6.2.2.6). 

The command should be issued with Terminate (parameter3) set to “Terminate transferring” in order to cancel the transfer while all data of the specified file are not transferred. 

When Terminate (parameter3) is set to “Terminate transferring”, data transfer with 0 byte is performed. 

An example of using the virtual file data is shown below. 

(ObjectHandle = 0x00000001, FileSize = 0x00100000) 

|In the case that all data are transferred|In the case that data transfer is canceled|
|---|---|
|The first time:<br>ObjectHandle = 0x00000001<br>TransferMaxSize = 0x00020000<br>Terminate = 0x00000000<br>The second time:<br>ObjectHandle = 0x00000001<br>TransferMaxSize = 0x00020000<br>Terminate = 0x00000000<br>The eighth time (last data acquisition):<br>ObjectHandle = 0x00000001<br>TransferMaxSize = 0x00020000<br>Terminate = 0x00000000|The first time:<br>ObjectHandle = 0x00000001<br>TransferMaxSize = 0x00020000<br>Terminate = 0x00000000<br>The second time:<br>ObjectHandle = 0x00000001<br>TransferMaxSize = 0x00020000<br>Terminate = 0x00000000<br>The third time (data transfer is canceled):<br>ObjectHandle = 0x00000001<br>TransferMaxSize = 0x00020000<br>Terminate = 0x00000001|



Do Not Copy 

78/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

The information necessary to maintain this command is released in any of the following conditions. 

After the information is released, the file data is acquired from the beginning if this command is issued again. 

|Termination condition|Reference|
|---|---|
|Thefile data specified by the ObjectHandle (parameter1)has beentransferred completely.|-|
|The parameter3 (Terminate) of this command is set to“Terminate transferring”.|-|
|The interval between the response of this command and the next issue of this command<br>exceeds approx. 60 seconds.<br>* If the file data offset of the response parameter is 0 after the second transfer of divided data<br>and before transfer of all data, it is regarded as a time-out.|-|
|A card has been ejected regardless of whether the card contains the file data specified by the<br>ObjectHandle or not.|-|
|The file has been deleted.|-|
|Movie recording or movie playback has started.|-|
|CloseSession command is executed.|6.2.1.3|
|GetObjectHandles commandis executed.|6.2.1.7|
|GetObjectInfo command is executed.|6.2.1.8|
|GetObject command is executed.|6.2.1.9|
|GetThumb command is executed.|6.2.1.10|
|DeleteObject command is executed.|6.2.1.11|
|SendObjectInfo commandis executed.|6.2.1.12|
|SendObject command is executed.|6.2.1.13|
|InitiateCapture command is executed.|6.2.1.14|
|FormatStore command is executed.|6.2.1.15|
|GetPartialObject command is executed.|6.2.1.19|
|ChangeApplicationMode commandis executed.|6.2.2.6|
|SaveCameraSetting command is executed.|6.2.2.8|
|GetObjectSize command is executed.|6.2.2.10|
|GetPartialObjectEx command is executed.|6.2.2.12|
|GetLargeThumb command is executed.|6.2.2.14|
|InitiateCaptureRecInMedia commandis executed.|6.2.2.18|
|StartMovieRecord command is executed.|6.2.2.39|
|InitiatePixelMapping commandis executed.|6.2.2.47|
|GetObjectPropValue command is executed.|6.2.2.59|
|GetObjectPropList commandis executed.|6.2.2.60|



## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|ObjectHandle||
|Parameter2|TransferMaxSize (Byte)||
|Parameter3|Terminate||
||0|Continue transferring|
||1|Terminate transferring|



Do Not Copy 

79/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|
||In the case of an ObjectHandle other than the image file|
||In the case of an ObjectHandle of the SDRAM|
|Store_Not_Available|The card is being initialized.|
||The card does not exist.|
||The batteryis exhausted.|
|Access_Denied|The movie is playing.|
|Invalid_Parameter|“Terminate” isneither0nor 1.|
|Invalid_Status|The application mode is set to OFF.|



## ○ **Response Parameter** 

|ResponseParameter|Description|
|---|---|
|Parameter1|The number of bytes actually sent|
|Parameter2|File data offset before command execution and data transfer (Lower<br>4Byte)|
|Parameter3|File data offset before command execution and data transfer (Upper<br>4Byte)|



Do Not Copy 

80/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.14 GetLargeThumb** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90C4|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|LargeThumbnail data|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires the large thumbnail data of the specified object. 

## ○ **Command Details** 

The camera sends all the large thumbnail data corresponding to the specified ObjectHandle to the host. 

When the specified ObjectHandle is the data in the card, the camera returns the large thumbnail data corresponding to the ObjectHandle. 

The ObjectHandle passed by ObjectAddedInSdram should be specified in order to acquire the information of the object in the SDRAM. 

The LargeThumbnail data is the large thumbnail data of the object (file) specified by the ObjectHandle.  The size of the LargeThumbnail data shall be the reference JPEG image size acquired in order of priority shown in the table below. 

|Order of priority|Reference<br>(Still image object)|Reference<br>(Movie object)|
|---|---|---|
|1|MPF class 1|MPF class 1|
|2|VIEW|MPF class 2|
|3|MPFclass2|Smallthumbnail|



The size of small thumbnail is the same as thumbnail that can be obtained with the GetThumb command (subsection 6.2.1.10). 

|Aspect ratio|VIEW|MPF class 1|MPF class 2|
|---|---|---|---|
|3:2|570x375|640x424|1620x1080|
|5:4||600x480|1350x1080|
|4:3||640x480|1440x1080|
|1:1||480x480|1080x1080|
|16:9||640x360|1920x1080|



- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|
||WAV format object is specified.|
||An object in the SDRAM other than the ObjectHandle passed by<br>ObjectAddedInSdram is specified.|
|No_Thumbnail_Present|The object corresponding to the specified ObjectHandle does not<br>include a thumbnail.|
|Store_Not_Available|The card is beinginitialized.|



Do Not Copy 

81/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

|**idential**|**Nikon Corporati**|
|---|---|
||The card does not exist.|
||The batteryis exhausted.|
|Access_Denied|The movie isplaying.|



Do Not Copy 

82/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.15 GetFhdPicture** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x920F|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|FullHD image data|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires the FullHD image data of the specified object in the card. 

## ○ **Command Details** 

The camera sends all the FullHD image data corresponding to the specified ObjectHandle in the card to the host. 

The FullHD image data is a maximum of 1920x1080-size JPEG image. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.<br>The object other than Jpeg, RAW or TIFF is specified.|
|No_FullHD_Present|An object that corresponds to the specified ObjectHandle is not the<br>FullHD image.|
|Store_Not_Available|The card is being initialized.|
||The card does not exist.|
||The battery is exhausted.|
|Access_Denied|The movie is playing.|



Do Not Copy 

83/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.16 CancelImagesInSdram** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x940C|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode cancels the transfer of a specific object saved in the SDRAM. 

## ○ **Command Details** 

This command cancels the transfer of the object corresponding to the specified ObjectHandle. For the ObjectHandle, the ObjectHandle passed by the ObjectAddedInSdram event should be specified.  When the object corresponding to the specified ObjectHandle has been already sent to the host or deleted, an error response is made. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Device_Busy|The shooting operation is being performed.<br>The ObjectAddedInSdram event is not ready for passing.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|



Do Not Copy 

84/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.17 DeleteImagesInSdram** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90C3|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode deletes a specific object saved in the SDRAM or all the objects saved in the SDRAM. 

## ○ **Command Details** 

The object that corresponds to the specified ObjectHandle is deleted.  All the objects in the SDRAM are deleted if the value of Parameter1 is 0.  During the process of deleting all the objects, the camera does not issue a new ObjectAddedInSdram event. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Device_Busy|The shooting operation is being performed.<br>The ObjectAddedInSdram event is not ready for passing.|
|Invalid_Object_Handle|An object that corresponds to the specified ObjectHandle does not<br>exist.|



Do Not Copy 

85/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.18 InitiateCaptureRecInMedia** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9207|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|
|Event Code|RefertoEvent Codeinthis subsection.|



## ○ **Command Outline** 

The operation by this OperationCode makes the camera start the acquisition of one or more new objects (release operation of the camera) according to the current setting.  The acquired object (image data) is saved in the specified location. 

## ○ **Command Details** 

This command is an activation-type command.  OK response is made when the start of the AF operation or the release operation is completed. 

When the host gets the response of the normal termination, the host should issue the DeviceReady command (subsection 6.2.2.2) to confirm whether the release operation is terminated. 

The following information can be returned for the DeviceReady command (subsection 6.2.2.2) when requesting the release operation. 

|Response Code|Description|
|---|---|
|OK|The release operation is normally terminated.|
|Device_Busy|The AF, the shooting or the continuous shooting operation is being<br>performed|
|Bulb_Release_Busy|The bulb shooting is being performed.|
|Silent_Release_Busy|The silent shootingis being performed.|
|Out_of_Focus|The AF operation is not focused before shooting or during continuous<br>shooting.|
|Wb_Preset_Error|The presetmeasurementreleasefailed.|
|Other Response Code|Some error has occurred when requesting the release.|



* For the details, refer to the DeviceReady command (subsection 6.2.2.2). 

Whether the AF operation is performed or not depends on the value of CaptureSort (described later) in Parameter1 and the focus mode setting.  When the live view is executed, it also depends on the live view mode. 

For the details of the command release operation, refer to Command Release Operation (subsection 11.7). 

Do Not Copy 

86/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|CaptureSort (The details are shown inthe table below.)||
|Parameter2|SaveMedia||
||0x0000|Card|
||0x0001|SDRAM|
||0x0002|Card and SDRAM|
|Parameter3|None||



|CaptureSort|Operation|Description|
|---|---|---|
|0xFFFFFFFE|Image acquisition release after<br>AF driving|The AF driving is started and then the release<br>operation of the camera is performed.<br>- Photo shooting<br>In the case of focus priority, the release operation is<br>started only when the AF is focused after AF driving.<br>Other than in the case of focus priority, the release<br>operation is always started independent of the<br>status after AF driving.<br>- Movie shooting<br>Because it is fixed to the release priority, the release<br>operation is always started independent of the<br>status after AFdriving.|
|0xFFFFFFFF|Image acquisition release|Normal release operation is performed.|
|0x00000001|Preset measurement release 1|Stores the acquired preset gain in D1.|
|0x00000002|Preset measurement release 2|Stores the acquired preset gain in D2.|
|0x00000003|Preset measurement release 3|Stores the acquired preset gain in D3.|
|0x00000004|Presetmeasurementrelease4|Stores the acquired preset gain in D4.|
|0x00000005|Preset measurement release 5|Stores the acquired preset gain in D5.|
|0x00000006|Preset measurement release 6|Stores the acquired preset gain in D6.|
|0x00000010|Dust reference image release|Dust reference image release operation is<br>performed.<br>When the shooting succeeds, the operation similar<br>to the image acquisition release is performed<br>hereafter.|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|The specified CaptureSort or SaveMedia is out of the<br>setting range.|
|Device_Busy|When the command processing is started, the acquisition<br>operation is being performed.|
||The shutter-release button is being fully pressed.|
||The STM lens is being initialized.|
|Hardware_Error|When the command processing is started, some error is<br>generated in the camera body.|
|Out_of_Focus|All of the following conditions are satisfied andthe AF<br>operation is not focused.<br>-CaptureSort is the image acquisition release after AF<br>driving.<br>-The AF operation mode is set to [Focus priority].<br>- TheLiveViewSelector is set to [Liveviewphotography].|
|Invalid_Status|The shutter speed is set to Time.|
|Dust_Reference_Error|The CPU internal lens is not mounted during the dust<br>reference image release.|
||The dust reference image release failed.|
||The dustreferenceimagereleaseis specifiedwhenthe|



Do Not Copy 

87/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

|**idential**|**Nikon Corporati**|
|---|---|
||HDR mode is set to [On].|
||The dust reference image release is specified when the<br>LiveViewSelector is set to [Movie mode].|
|Wb_Preset_Error|The preset measurement release is specified when the<br>LiveViewSelector is set to [Moviemode].|
||The preset measurement release is specified when the<br>ExposureProgramMode property (subsection 6.5.1.11) is<br>set to anything other than PSAM.|
||The preset manual WB data save destination that is<br>specified in the preset measurement release is protected.|
||The preset measurement release is specified when the<br>HDR modeis set to ON.|
||The preset measurement release is specified during PC<br>camera mode.|
|CameraMode_Not_Adjust_Fnumber|An aperture value error occurs.|
|Store_Full|There is no free area for recording in the card.|
||Thereisnofree areafor recordinginthe SDRAM.|
|Store_Not_Available|The card is beinginitialized|
||The card does not exist when SaveMedia is set to [Card] or<br>[Card and SDRAM].|
||The batteryis exhausted.|
|Store_Error|SaveMedia is [Card] or [Card and SDRAM] and a card<br>access error occurs in the camera.|
|Store_Unformatted|SaveMedia is [Card] or [Card and SDRAM] and the card is<br>not formatted.|
|Store_Read_Only|The card that is ready for recording is protected.|
|Access_Denied|In the case of the spot WB acquisition standby state|
||When a retractable lens is mounted, the lens is retracting.|
||TheMovieLogOutput property (subsection6.5.7.27)is [On].|
||The WarningStatus property (subsection 6.5.7.23) is<br>“Version upgrade warning when mount adapter is<br>attached”.|
||The MovieRecordScreenSize property (subsection 6.5.3.3)<br>is set to [3840x2160 60p] or [3840x2160 50p]|
||The DX lens is mounted during the dust reference image<br>release.|
||Shooting cannot be performed depending on the camera<br>status by a cause otherthanthe above.|



- **Event Code** 

|Event Code|Description|
|---|---|
|ObjectAdded|A newobjectisrecordedinthe card.|
|StoreFull|There is no free area for recording in the card after shooting.|
|CaptureComplete|The acquisition operation of all the new objects is completed.|
|ObjectAddedInSdram|A new object is recorded in the SDRAM.|
|CaptureCompleteRecInSdram|All the images captured by this command are sent from the<br>SDRAMto thehost completely.|



Do Not Copy 

88/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.19 InitiateCaptureRecInSdram** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90C0|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode makes the camera start the acquisition of one or more new objects (release operation of the camera) according to the current setting.  The acquired object (image data) is saved in the SDRAM. 

## ○ **Command Details** 

This command performs the same operation as that of the InitiateCaptureRecInMedia command with CaptureSort set to a value other than [Image acquisition release after AF driving] and SaveMedia set to [SDRAM]. 

The parameters to perform the same operation as that of InitiateCaptureRecInSdram by InitiateCaptureRecInMedia are shown below. 

|Operation Parameter||
|---|---|
|Parameter1(CaptureSort)|0x00000010(DustOff)<br>0xFFFFFFFF(Image acquisition release)|
|Parameter2(SaveMedia)|0x00000001(SDRAM)|



For the details, refer to the InitiateCaptureRecInMedia command (subsection 6.2.2.18). 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|CaptureSort<br>Refer to the InitiateCaptureRecInMedia command.|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

This subsection describes only ResponseCodes different from that of the InitiateCaptureRecInMedia command. 

|**Response Code**<br>This subsection describes only ResponseCodes different from that of the<br>itiateCaptureRecInMedia command.|**Response Code**<br>This subsection describes only ResponseCodes different from that of the<br>itiateCaptureRecInMedia command.|**Response Code**<br>This subsection describes only ResponseCodes different from that of the<br>itiateCaptureRecInMedia command.|
|---|---|---|
|For the details of other response codes, refer to the InitiateCaptureRecInMedia command.<br>Response Code<br>Description<br>Shutter_Speed_Bulb<br>The shutter speed is set to Bulb.<br>Shutter_Speed_Time<br>The shutterspeedis set toTime.|||
||Response Code|Description|
||Shutter_Speed_Bulb|The shutter speed is set to Bulb.|
||Shutter_Speed_Time|The shutterspeedis set toTime.|



Do Not Copy 

89/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.20 AfAndCaptureRecInSdram** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90CB|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode starts the AF driving and makes the camera start the acquisition of one or more new objects (release operation of the camera).  The acquired object (image data) is saved in the SDRAM. 

## ○ **Command Details** 

This command performs the same operation as that of the InitiateCaptureRecInMedia command with CaptureSort set to [Image acquisition release after AF driving] and SaveMedia set to [SDRAM]. 

The parameters to perform the same operation as that of AfAndCaptureRecInSdram by InitiateCaptureRecInMedia are shown below. 

|Operation Parameter|Description|
|---|---|
|Parameter1 (CaptureSort)|0xFFFFFFFE (Image acquisition release after AF driving)|
|Parameter2 (SaveMedia)|0x00000001(SDRAM)|



For the details, refer to the InitiateCaptureRecInMedia command (subsection 6.2.2.18). 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

This subsection describes only ResponseCodes different from that of the InitiateCaptureRecInMedia command. 

For the details of other response codes, refer to the InitiateCaptureRecInMedia command. 

|Response Code|Description|
|---|---|
|Shutter_Speed_Bulb|The shutter speed is set to Bulb.|
|Shutter_Speed_Time|The shutter speed is set to Time.|



Do Not Copy 

90/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.21 TerminateCapture** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x920C|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode stops the shooting operation executed by the host. 

## ○ **Command Details** 

The camera stops the following shooting operation executed by the host. 

|Shooting operation|Operation after stopping|
|---|---|
|Bulb shooting|The images captured until the operation is stopped are recorded in the<br>card orthe SDRAM.|
|Continuous shooting|If this command is executed during continuous shooting, the shooting<br>operation is terminated.|



The transition to the response phase is performed when the start of the shooting stop processing is completed. 

- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|Reserved(0)|
|Parameter2|Reserved (0)|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|



Do Not Copy 

91/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.22 AfDrive** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90C1|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode starts the AF driving and has the same function as that of pressing the shutter-release button of the camera body halfway. 

## ○ **Command Details** 

This command is an activation command.  When the AF driving is started or the camera is in the AF non-driving condition described below, the OK response is made. 

After the command is terminated normally, the host should issue the DeviceReady command to confirm the completion of the operation. 

The following information can be returned for the DeviceReady command when the AF driving is started. 

|Response Code|Description|
|---|---|
|OK|AF driving operation is terminated.|
|Device_Busy|AF is in operation.|
|Out_of_Focus|AF operation failed (out of focus).|
|Other Response Code|AF operation failed.|



For the details, refer to the DeviceReady command (subsection 6.2.2.2). 

If the following conditions are true, the AF operation is not performed and the camera immediately returns OK. 

|No|AF non-driving condition|AF non-driving condition|
|---|---|---|
|1|Thevalue oftheFocusMode property (subsection6.5.1.7)is 0x0001[MF].||
|2|The value of the RetractableLensWarning property (subsection 6.5.10.9) is 1[(Retractable lens<br>warning) On].||
|**Oper**|**ation Parameter**||
||Operation Parameter|Details|
|Parameter1||None|
|Parameter2||None|
|Parameter3||None|



- **Operation Parameter** 

- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Device_Busy|When the command processing is started, the acquisition operation or<br>the AF operation is being performed.|
||The STM lens is being initialized.|



Do Not Copy 

92/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.23 AfDriveCancel** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9206|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode cancels the AF driving. 

## ○ **Command Details** 

The camera cancels the AF driving in operation. 

The transition to the response phase is performed when the cancellation of the AF driving is completed. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|



Do Not Copy 

93/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.24 MfDrive** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9204|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode starts the MF driving. 

## ○ **Command Details** 

This command is an activation command.  OK response is made when the MF driving is started. When the host gets the response of the normal termination, the host should issue the DeviceReady command to confirm whether the operation is terminated. 

The following information can be returned for the DeviceReady command when the MF driving is started. 

|Response Code|Description|
|---|---|
|OK|MF driving operation is terminated.|
|Device_Busy|MF is driving.|
|MfDrive_Step_End|The MF driving reaches the end of steps.|
|MfDrive_Step_Insufficiency|The driving amount is insufficient.|
|Other Response Code|The MF driving operation failed.|



* For the details, refer to the DeviceReady command (subsection 6.2.2.2). 

The camera performs the MF driving based on the contents of DriveType specified by Parameter1. The MF driving amount is based on the contents of StepValue specified by Parameter2.  The MF driving operates according to the current position. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|DriveType||
||0x00000001|No limit->Closest|
||0x00000002|Closest->No limit|
|Parameter2|StepValue (driving amount (the number of pulses))||
||From 1to 32767||
|Parameter3|None||



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Device_Busy|The AF operation is being performed in the camera.|
||The AF-F is being set.|
||The STM lens is being initialized.|
||When the command processing is started, the acquisition operation is<br>being performed.|
|Invalid_Parameter|The specified value of DriveType or StepValue is out of the range.|
|Invalid_Status|The MF driving cannot be performed due to a problem caused by the<br>camera (an error caused by the camera, the CPU internal lens is not<br>mounted; the lens cannot be used, etc.).|
||The focus mode is MF.|



Do Not Copy 

94/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.25 ChangeAELock** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9426|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode changes the state of AE lock. 

- **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|LockValue||
||0|AE lock released|
||1|AE locked (hold)|
|Parameter2|None||
|Parameter3|None||



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Invalid_Parameter|The specifiedvalueis out oftherange.|
|Access_Denied|The WarningStatus property (subsection 6.5.7.23) is [Sequence<br>error], [Minimum aperture warning] or [Retractable zoom-ring<br>warning].|
||Waiting for spot WB data acquisition|
||During aperture preview.|
|Device_Busy|When the command processing is started, the acquisition operation is<br>being performed.|



Do Not Copy 

95/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.26 StartLiveView** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9201|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode makes the camera enter the remote live view status. 

## ○ **Command Details** 

This command is an activation-type command.  OK response is made when the entry into the remote live view status is started. 

When the host gets the response code of normal termination, the host should issue the DeviceReady command to confirm whether the camera enters the remote live view status (and the acquisition of the live view image becomes enabled). 

The following information can be returned for the DeviceReady command when entering the remote live view status. 

|Response Code|Description|
|---|---|
|OK|The camerahas entered theremoteliveviewstatus.|
|Device_Busy|The camera is entering the remote live view status.|
|Other Response Code*|Some error has occurredwhenentering theremoteliveviewstatus.|



* For the details, refer to the DeviceReady command (subsection 6.2.2.2). 

When the live view is active on the camera but the camera does not enter the remote live view status because the StartLiveView command is not executed, commands such as GetLiveViewImageEx command cannot be executed. 

The live view prohibition condition is shown in the LiveViewProhibitionCondition property (subsection 6.5.12.7).  The StartLiveView command must be issued when there is no prohibition factor in the LiveViewProhibitionCondition property.  If there is any prohibition factor in the LiveViewProhibitionCondition property, even if the StartLiveView command is issued and the live view is started, the operation is not guaranteed. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Device_Busy|When the command processing is started, the acquisition operation is<br>being performed.|
|Hardware_Error|When the command processing is started, some error is generated in<br>the camera body.|
|Invalid_Status|An error caused by the camera (battery empty, warning information)<br>occurs.|



Do Not Copy 

96/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.27 EndLiveView** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9202|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode releases the live view status. 

## ○ **Command Details** 

The remote live view status is released and the camera becomes into the camera live view status. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Device_Busy|Theliveviewcannot be terminated because ofthe camerafactor.|



Do Not Copy 

97/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.28 GetLiveViewImage** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9203|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|LiveViewObject (without version)|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires the newest live view image. The format of the live view image is JPEG. 

## ○ **Command Details** 

This OperationCode is a command for compatibility with the GetLiveViewImageEx command (subsection 6.2.2.29). 

For this camera, GetLiveViewImageEx command should be used. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Incomplete_Transfer|The data block transmission failed.|
|Access_Denied|The WarningStatus property (subsection 6.5.7.23) is “Version upgrade<br>warningwhen mount adapter is attached”.|
|Not_LiveView|The camera is not in the remote live view condition.|



Do Not Copy 

98/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.29 GetLiveViewImageEx** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9428|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|LiveViewObject (with version)|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires the newest live view image. The format of the live view image is JPEG. 

## ○ **Command Details** 

This command is valid when the camera is in the remote live view condition after executing the StartLiveView command. 

The camera sends the newest live view image (LiveViewObject) to the host.  LiveViewObject is composed of the display information and the live view image (JPEG). 

The data set of LiveViewObject is described in subsection 9.7. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|Access_Denied|The WarningStatus property (subsection 6.5.7.23) is “Version upgrade<br>warning when mount adapter is attached”.|
|Not_LiveView|The cameraisnotintheremoteliveviewcondition.|



Do Not Copy 

99/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.30 GetLiveViewCompressedSize** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9423|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|LiveViewObjectMaxSize Value|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires the maximum size (Byte) of LiveViewObject returned by the GetLiveViewImageEx command. 

## ○ **Command Details** 

The size of the live view image is calculated with the value set in the LiveViewImageCompression property and LiveViewImageSize property. 

The format of LiveViewObjectMaxSize is UINT32. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Incomplete_Transfer|The data block transmission failed.|



Do Not Copy 

100/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.31 ChangeAfArea** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9205|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode changes the AF area in the live view condition. 

## ○ **Command Details** 

This command is valid when the camera is in the remote live view condition after getting the StartLiveView command. 

The camera specifies the AF area with the coordinates specified by Parameter1 and Parameter2 set to the center.  XValue of Parameter1 and YValue of Parameter2 are used to set the X-axis and the Y-axis, respectively. 

The range of XValue and YValue should be the “Whole size” of the header information acquired by the GetLiveViewImageEx command.  However, the range that can be specified should be smaller by the half size of the “AF frame size”.  When a value that exceeds the setting permitted range is set, the maximum or the minimum value is reflected. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|XValue|
|Parameter2|YValue|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Access_Denied|Inthe case ofthe spotWBacquisitionstandby state|
|Device_Busy|The AF operation is being performed in the camera.|
|Not_LiveView|The cameraisnotintheremoteliveviewcondition.|



Do Not Copy 

101/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.32 StartTracking** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9424|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode starts tracking action for auto-area AF or changes the selected face. 

## ○ **Command Details** 

The specification method of OperationParameter is the same as the command details of ChangeAfArea (subsection 6.2.2.31). 

After this command is executed, LiveViewObject of the GetLiveViewImage command (subsection 

## 6.2.2.28) changes as follows. 

|Condition||Value of LiveViewObject that changes after this command is executed|Value of LiveViewObject that changes after this command is executed|Value of LiveViewObject that changes after this command is executed|
|---|---|---|---|---|
|Detected faces|Tracking<br>state|Tracking<br>state|Centercoordinatesof AF<br>frame|Index of selected face|
|There is a detected<br>face at the specified<br>coordinates.|Waiting<br>Selecting<br>Tracking|Waiting|-|Index of the faceat the<br>specified coordinates|
|There is no detected<br>face at the specified<br>coordinates.|Waiting<br>Selecting<br>Tracking|Tracking|Specified coordinates|-|



- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|XValue|
|Parameter2|YValue|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Access_Denied|The StillFocusMeteringMode property (subsection 6.5.2.61) is set to<br>the value other than [Auto-area AF mode (including person/animal)]<br>during live view photography.|
||The MovieFocusMeteringMode property (subsection 6.5.3.54) is set to<br>the value other than [Auto-area AF mode (including person/animal)]<br>duringmovieliveview.|
||In the case of the spot WB acquisition standby state|
|Device_Busy|Theimage acquisitionoperation is being performed.|
|Invalid_Status|Failed to change the tracking statedue to the camera factor.|
|Not_LiveView|The cameraisnotintheremoteliveviewcondition.|



Do Not Copy 

102/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.33 EndTracking** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9425|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode terminates the tracking operation in auto-area AF. 

## ○ **Command Details** 

After executing this command, the tracking state of LiveViewObject acquired by the GetLiveViewImageEx command (subsection 6.2.2.29) is set to [Waiting]. 

- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Device_Busy|The image acquisition operation is being performed.|
|Invalid_Status|Failed to change the tracking state due to the camerafactor.|
|Not_LiveView|The camera is not in the remote live view condition.|



Do Not Copy 

103/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.34 StartSpotWb** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9402|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode makes the camera enter into the spot WB acquisition standby state in the live view condition. 

## ○ **Command Details** 

This command is valid when the camera is in the remote live view condition after setting LiveViewSelector to [Movie live view] and executing the StartLiveView command. 

The camera enters into the acquisition standby state for the storage destination specified by the MovieWbPresetDataNo property (subsection 6.5.3.21).  When the MovieWhiteBalance (subsection 6.5.3.9) is set to [Same as photo settings], the storage destination specified by the WbPresetDataNo property is used. 

A property other than the following cannot be set in the spot WB acquisition standby state.  If it is set, the Access_Denied response is made. 

|Property Code|Description|Reference item|
|---|---|---|
|0x500E|ExposureProgramMode|6.5.1.11|
|0x5013|StillCaptureMode|6.5.1.15|
|0xD1BD|LiveViewZoomArea|6.5.12.6|



- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Access_Denied|The white balance is set to anything other than [Preset manual].|
||During the PC camera mode.|
||The LiveViewSelector property (subsection 6.5.12.8) is set to [Live<br>view photography].|
|Device_Busy|The shooting operation is being performed at the start of command<br>processing.|
|Invalid_Status|The storage destinationofthe presetmanual WBdatais protected.|
|Not_LiveView|The camera is not in the remote live view condition.|



Do Not Copy 

104/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.35 EndSpotWb** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9403|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode cancels the spot WB acquisition standby state. 

## ○ **Command Details** 

This command cancels the spot WB acquisition standby state. 

The OK response is made even when the camera is not in the spot WB acquisition standby state. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Device_Busy|During transition into the spot WB condition|
|Not_LiveView|The cameraisnotintheremoteliveviewcondition.|



Do Not Copy 

105/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.36 ChangeSpotWbArea** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9404|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode changes the spot WB area in the spot WB acquisition standby state. 

## ○ **Command Details** 

This command is valid when the camera is in the spot WB acquisition standby state after getting the StartSpotWb command. 

For the details, refer to ChangeAfArea (subsection 6.2.2.31). 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|XValue|
|Parameter2|YValue|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Invalid_Status|The camera is not in the spot WB acquisition standby state.|
|Not_LiveView|The cameraisnotintheremoteliveviewcondition.|



Do Not Copy 

106/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.37 MeasureSpotWb** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9405|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires the spot WB in the spot WB acquisition standby state. 

## ○ **Command Details** 

This command is valid when the camera is in the spot WB acquisition standby state after getting the StartSpotWb command (subsection 6.2.2.34). 

This command is an activation command.  When the spot WB acquisition is started, the transition to the response phase is performed. 

When receiving this command, the camera acquires the spot WB with the coordinates set by ChangeSpotWbArea command (subsection 6.2.2.36). 

The spot WB acquisition result is passed by the display information in LiveViewObject acquired by GetLiveViewImageEx command (subsection 6.2.2.29). 

After releasing the acquisition result, the camera is in the spot WB acquisition standby state and the acquisition operation can be performed again by executing this command. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Device_Busy|During transition into the spotWBcondition|
|Invalid_Status|The camera is not in the spot WB acquisition standby state.|
|Not_LiveView|The cameraisnotintheremoteliveviewcondition.|



Do Not Copy 

107/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.38 EndSpotWbResultDisp** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9406|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode cancels the spot WB acquisition result screen display. 

## ○ **Command Details** 

This command cancels the spot WB acquisition result screen display. 

The OK response is made even while the spot WB acquisition result screen is not displayed. This command is an activation command.  When the cancellation of the spot WB acquisition result screen display is started, the transition to the response phase is performed. 

The result of the spot WB acquisition result screen display is passed by the display information in LiveViewObject acquired by the GetLiveViewImageEx command (subsection 6.2.2.29). 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Not_LiveView|The cameraisnotintheremoteliveviewcondition.|



Do Not Copy 

108/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.39 StartMovieRecord** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x920A|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|Refer to Response Parameter in this subsection.|



## ○ **Command Outline** 

The operation by this OperationCode starts movie recording. 

## ○ **Command Details** 

This command is accepted only during the live view execution.  It is recommended to check the movie recording prohibition condition property (MovieRecProhibitionCondition (subsection 6.5.7.25)) before issuing this command. 

- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Access_Denied|In the case of the spot WB acquisition standby state|
|Invalid_Status|The movie recording cannot be started due to an error caused by the<br>camera.|
|Not_LiveView|The camera is not in the live view condition.|



## ○ **Response Parameter** 

|ResponseParameter|Description|
|---|---|
|Parameter1|When the response code is OK, the recording media is specified in this<br>field.<br>When the response code is not OK, this field is invalid.<br>0: Recording in the card<br>1: Recording in the external recorder<br>2: Recording in the card and the external recorder|
|Parameter2|None|
|Parameter3|None|



Do Not Copy 

109/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.40 EndMovieRecord** 

## ○ **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x920B|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode finishes movie recording. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|Anunsupported parameter is specified.|



Do Not Copy 

110/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.41 ResetMenu** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9436|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode resets the camera settings. 

## ○ **Command Details** 

The setting value that is specified in Parameter1 (Reset Type) is reset. 

White balance, white balance sub-item, fine tuning values other than preset manual data, and preset manual data number are reset. 

In the case of resetting file number sequence, the value of “Custom menu – Shooting/display – File number sequence” is reset. 

## ○ **Operation Parameter** 

|Operation Parameter|詳細|詳細|詳細|
|---|---|---|---|
|Parameter1|Reset Type||Bank can be<br>specified|
||0x0001|Photo shootingmenu|no|
||0x0002|White balance (Photography)|no|
||0x0101|Movie shooting menu|no|
||0x0102|White balance (Movie)|no|
||0x0201|Custom menu|no|
||0x0202|Filenumbersequence|no|
|Parameter2|[Bank]*Not used in this camera|||
||None|Bank in use||
||0|||
||1|Bank A||
||2|Bank B||
||3|Bank C||
||4|Bank D||
|Parameter3|None|||



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Invalid_Parameter|The specified value is out of the range.|
|Access_Denied|Movie shooting menu is specified when saving the movie frame.|
||Inthe case ofthe spotWBacquisitionstandby state|
||[File number sequence] is specified when the HDRMode property<br>(subsection 6.5.2.64) is set to [On].|
|Device_Busy|The shooting operation is being performed at the start of command<br>processing.|



Do Not Copy 

111/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.42 SetPreWbData** 

## ○ **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90C9|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|PreWbThumImage|
|Data direction|From host to camera|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode sets the data in the preset manual white balance data area of the camera. 

## ○ **Command Details** 

This command sets the data in the preset manual white balance data area of the camera. 

The camera stores the preset white balance gain value specified by PreWbGainValue in the data area specified by PreWbDataIndex and stores the thumbnail image of PreWbThumImage. 

The format of PreWbThumImage shall be the same as that of the thumbnail image (JPEG format) recorded in the JPEG file defined in the accompanying document “RAW Data Format for Digital Camera”. 

When PreWbThumImageSize is 0, PreWbThumImage is not sent in the data phase and the thumbnail image is not recorded. 

Do Not Copy 

112/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|byte3: Reserved(0)||
||byte2:ShootingMode||
||0|Photography|
||1|Movie|
||byte1: RotateThumb (*1)||
||0|Horizontal|
||1|Grip side upward|
||2|Grip side downward|
||byte0: PreWbDataIndex (*2)<br>This is equivalent to the WbPresetDataNo property (subsection<br>6.5.2.26).||
|Parameter2|PreWbGainValue||
|Parameter3|PreWbThumImageSize||



- *1: RotateThumb is referred to by the camera when Parameter3 (PreWbThumImageSize) is a value other than 0. 

- *2: If the value of the WbPresetDataNo property is zero (in the case of the camera with acquired data), any data cannot be set in the preset manual white balance data area. 

The contents of PreWbGainValue are shown below. 

Upper 2 Bytes of PreWbGainValue are RGain and lower 2 Bytes are BGain. 

The format of RGain and BGain is fixed point. RGain sets Bit 16 to 26 as decimal parts and BGain sets up to Bit 10 as decimal parts. 

Since the number of significant digits of the decimal part is 9 bits, the lower 2 bits are ignored. 

**==> picture [86 x 52] intentionally omitted <==**

The range that can be set for RGain, BGain is as follows. 

0 ≤RGain < 8 × 2048 

0 ≤BGain < 8 × 2048 

||||||PreWbGainValue|PreWbGainValue|PreWbGainValue|PreWbGainValue|PreWbGainValue|PreWbGainValue|PreWbGainValue|PreWbGainValue|PreWbGainValue|PreWbGainValue|PreWbGainValue|
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|
|Integer part|||||Decimal part|||||||||||
|15|14|13|12|11|10|9|8|7|6|5|4|3|2|1|0|
|Integer part|||||Decimal part|||||||||||



PreWbThumImageSize indicates the size of PreWbThumImage.  In addition, PreWbThumImage should be the compression quality Fine (1/4 compression) and the size should be 13440 bytes or less. 

## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Incomplete_Transfer|The data block reception failed.|
|Device_Busy|During shooting by the camera|
|Invalid_Parameter|The specified value is out of the range.|
|Wb_Preset_Error|The specifiedindexofthe presetis protected.|



Do Not Copy 

113/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.43 GetPicCtrlData** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90CC|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|PictureControl DataSet|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires PictureControl DataSet of the specified PicCtrlItem. 

## ○ **Command Details** 

The parameter3 is optional and the photo shooting menu or movie shooting menu can be specified. 

For the format of the PictureControl DataSet, refer to subsection 9.8. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|PicCtrlItem (equivalent to the ActivePicCtrlItem property (subsection<br>6.5.13.1)||
|Parameter2|DefaultFlag||
||0|The current setting value|
||1|The default value|
|Parameter3|[ShootingMode]||
||None|PictureControl data for the photo shooting menu|
||0||
||1|PictureControldataforthemovie shootingmenu|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|The specified value is out of the range.|
|Incomplete_Transfer|The data block transmission failed.|



Do Not Copy 

114/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.44 SetPicCtrlData** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90CD|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|PictureControl DataSet|
|Data direction|From host to camera|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode sets PictureControl DataSet to the specified PicCtrlItem. 

## ○ **Command Details** 

The parameter3 is optional and the photo shooting menu or movie shooting menu can be specified. 

For the format of the PictureControl DataSet, refer to subsection 9.8. 

- **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|PicCtrlItem (equivalent to the ActivePicCtrlItem property (subsection<br>6.5.13.1))||
|Parameter2|ModifiedFlag||
||0|The contents of PictureControl DataSet are applied as a new<br>picture control.|
||1|The contents of PictureControl DataSet are applied to the<br>current settingvalue ofthe existing picture control.|
|Parameter3|[ShootingMode]||
||None|PictureControl data for the photo shooting menu|
||0||
||1|PictureControl data for the movie shooting menu|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|The specified value is out of the range.|
|Incomplete_Transfer|The data blocktransmission failed.|
|Device_Busy|During shooting by the camera|
|Access_Denied|When PicCtrlItem is a custom picture control and ModifiedFlag is set<br>to 1, the registered base picture control and BasePictureControl in<br>PictureControl DataSet do not match.|
||InvalidPictureControl DataSet (subsection9.8)is specified.|



Do Not Copy 

115/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.45 DeleteCustomPicCtrl** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90CE|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode deletes the specified custom picture control item. 

## ○ **Command Details** 

The contents of CustomPicCtrlItem are the same as those of ActivePicCtrlItem property (subsection 6.5.13.1). 

- **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|CustomPicCtrlItem||
|Parameter2|[ShootingMode]||
||None|PictureControl data for the photo shooting menu|
||0||
||1|PictureControl data for the movie shooting menu|
|Parameter3|None||



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|The specified value is out of the range.|
|Device_Busy|During shooting by the camera|
|Access_Denied|An attempt is made to delete the custom picture control that is<br>selectedinthe user mode.|



Do Not Copy 

116/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.46 GetPicCtrlCapability** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x90CF|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|PictureControlCapabilityData|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires PictureControlCapability DataSet of the picture control that is the basis of the specified PicCtrlItem. 

## ○ **Command Details** 

The parameter2 is optional and the photo shooting menu or movie shooting menu can be specified. 

For the format of the PictureControlCapability DataSet, refer to subsection 9.9. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|PicCtrlItem (equivalent to the ActivePicCtrlItem property (subsection<br>6.5.13.1))||
|Parameter2|[ShootingMode]||
||None|PictureControl data for the photo shooting menu|
||0||
||1|PictureControl data for the movie shooting menu|
|Parameter3|None||



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|The specifiedvalueis out oftherange.|
|Incomplete_Transfer|The data block transmission failed.|



Do Not Copy 

117/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.47 InitiatePixelMapping** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9433|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode starts pixel mapping. 

## ○ **Command Details** 

This command is an activation command.  The camera returns OK after starting pixel mapping operation. 

When pixel mapping operation is completed, the camera sends PixelMappingComplete event (subsection 6.4.2.8). 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Device_Busy|The shooting operation is being performed at the start of command<br>processing.|
|Access_Denied|Sequence error.|
||The batteryis exhausted.|
||Temperature in the camera exceeds the specified value.|
||Wirelessremote control is connected.|



Do Not Copy 

118/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.48 GetManualSettingLensData** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|OperationCode|0x9432|
|Operation Parameter|Refer to Operation Parameter in this subsection.|
|Data|ManualSettingLensDataSet|
|Data direction|From camera to host|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires the information about “Non-CPU lens data” in the setup menu. 

## ○ **Command Details** 

The camera sends the information (ManualSettingLens DataSet) about “Non-CPU lens data” of LensNo specified by the parameter1 to the host. 

When 0xFFFFFFFF is set to LensNo, the camera sends all the information to the host. 

## The ManualSettingLens DataSet is shown below. 

|Field|Field|Size|Description|
|---|---|---|---|
|Lens No. being set||4|Refer to ManualSettingLensNo property (subsection 6.5.5.1).|
|Number of manual setting lens information<br>(N)||4|Acquire one data：1/ Acquire all data：20|
|Manual setting lens<br>information[0]|Focal length|2|Information about the lens No. 1.*<br>* When “Acquire one data” is selected, the information about the<br>lens of LensNo specified by Parameter1.<br>Focal length：Refer to FmmManualSetting property (subsection<br>6.5.5.2).<br>Maximum aperture：Refer to F0ManualSetting property<br>(subsection 6.5.5.3).|
||Maximum<br>aperture|2||
|Manual setting lens<br>information [1]|Focal length|2|Information about the lens No. 2.|
||Maximum<br>aperture|2||
|Manual setting lens<br>information [N - 1]|Focal length|2|Information about the lens No. N.|
||Maximum<br>aperture|2||



## ○ **Operation Parameter** 

|Operation Parameter|Description|Description|
|---|---|---|
|Parameter1|LensNo||
||Refer to ManualSettingLensNo property (subsection<br>6.5.5.1).|Acquire one data|
||0xFFFFFFFF|Acquire all data|
|Parameter2|None||
|Parameter3|None||



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|The specifiedvalueis out oftherange.|
|Incomplete_Transfer|The data block transmission failed.|



Do Not Copy 

119/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.49 GetSBHandles** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9414|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|SBHandleList|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the handle of the flash attached with the camera. 

## ○ **Command Details** 

When the parameter1 (SBGroupID, subsection 7.6) is specified, the handle of the flash in the specified group is transferred. 

When the parameter1 (SBGroupID, subsection 7.6) is not specified or set to zero, the handles of all flash are transferred. 

## The data set of SBHandleList is shown below. 

|Field|DataSize|DataType|Description|
|---|---|---|---|
|NumberOfElements|4|UINT32|The number of SBHandle in the list.|
|Element1 SBHandle|4|SBHandle|The handle of the element1 flash.|
|Element2SBHandle|4|SBHandle|Thehandle ofthe element2 flash.|
|||…||
|ElementNSBHandle|4|SBHandle|Thehandle ofthe elementN flash.|



- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|[SBGroupID]|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Parameter|Invalid SBGroupID is specified.|



Do Not Copy 

120/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.50 GetSBAttrDesc** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9415|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|SBHandleAttributeDescList|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the descriptor of the attribute for the flash. 

## ○ **Command Details** 

When the parameter1 (SBHandle, subsection 7.5) is specified, the descriptor for the specified flash is transferred.  When the parameter1 (SBHandle, subsection 7.5) is not specified or set to zero, the descriptors for all flash are transferred. 

When the parameter2 (SBAttrID) is specified, the descriptor for the specified SBAttribute (subsection 6.7.1) is transferred.  When the parameter2 (SBAttrID) is not specified, the descriptors for all SBAttribute are transferred. 

## The data set of SBHandleAttributeDescList is shown below. 

|Field|DataSize|DataType or DataSet|Description|
|---|---|---|---|
|NumberOfElements|4|UINT32|ThenumberofSBHandleinthelist.|
|Element1 SBHandle|4|SBHandle|SBHandle for element1.|
|Element1<br>SBAttributeDescList|DTS|SBAttributeDescList<br>(subsection9.11)|Attribute descriptor of the element1 flash.|
|Element2 SBHandle|4|SBHandle|SBHandle for element2.|
|Element2<br>SBAttributeDescList|DTS|SBAttributeDescList|Attribute descriptor of the element2 flash.|
|||…||
|ElementNSBHandle|4|SBHandle|SBHandleforelementN.|
|ElementN<br>SBAttributeDescList|DTS|SBAttributeDescList|Attribute descriptor of the element N flash.|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|[SBHandle]|
|Parameter2|[SBAttrID]|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Parameter|Invalid SBHandleis specified.|
||Invalid SBAttrID is specified.|
||Valid SB informationcannot be acquired.|



Do Not Copy 

121/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.51 GetSBAttrValue** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9416|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|SBHandleAttributeList|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the current attribute value for the specified flash. 

## ○ **Command Details** 

When the parameter1 (SBHandle, subsection 7.5) is specified, the value for the specified flash is transferred.  When the parameter1 (SBHandle, subsection 7.5) is not specified or set to zero, the values for all flash are transferred. 

When the parameter2 (SBAttrID) is specified, the value for the specified SBAttribute (subsection 6.7.1) is transferred.  When the parameter2 (SBAttrID) is not specified, the values for all SBAttribute are transferred. 

## The data set of SBHandleAttributeList is shown below. 

|Field|DataSize|DataType or DataSet|Description|
|---|---|---|---|
|NumberOfElements|4|UINT32|ThenumberofSBHandleinthelist.|
|Element1 SBHandle|4|SBHandle|SBHandle for element1.|
|Element1<br>SBAttributeList|DTS|SBAttributeList<br>(subsection9.13)|SBAttributeList for element1.|
|Element2 SBHandle|4|SBHandle|SBHandle for element2.|
|Element2<br>SBAttributeList|DTS|SBAttributeList|SBAttributeList for element2.|
|||…||
|ElementNSBHandle|4|SBHandle|SBHandleforelementN.|
|ElementN<br>SBAttributeList|DTS|SBAttributeList|SBAttributeList for element N.|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|[SBHandle]|
|Parameter2|[SBAttrID]|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Parameter|Invalid SBHandleis specified.|
||Invalid SBAttrID is specified.|
||Valid SB informationcannot be acquired.|



Do Not Copy 

122/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.52 SetSBAttrValue** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9417|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|SBHandleAttributeList|
|Data direction|From host to camera|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode updates the current attribute value for the specified flash. 

## ○ **Command Details** 

## The data set of SBHandleAttributeList is shown below. 

|Field|DataSize|DataType or Data Set|Description|
|---|---|---|---|
|NumberOfElements|4|UINT32|The number of SBHandle in the list.|
|Element1 SBHandle|4|SBHandle|SBHandle for element1.|
|Element1<br>SBAttributeList|DTS|SBAttributeList<br>(subsection 9.13)|SBAttributeList for element1.|
|Element2 SBHandle|4|SBHandle|SBHandle for element2.|
|Element2<br>SBAttributeList|DTS|SBAttributeList|SBAttributeList for element2.|
|||…||
|ElementN SBHandle|4|SBHandle|SBHandle for element N.|
|ElementN<br>SBAttributeList|DTS|SBAttributeList|SBAttributeList for element N.|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Parameter|Invalid SBHandle is specified.|
||Invalid SBAttrID is specified.|
|Invalid_SBAttribute_Value|The specified attribute value is not supported.|
|Access_Denied|The specified flash is not in a settable state.|
||An operation is denied depending on the status of the camera.|
||The specified SBAttributeCode is not permitted for setting.|
|Device_Busy|The shooting operation or the AF operation is being performed when<br>starting this command.|



Do Not Copy 

123/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.53 GetSBGroupAttrDesc** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9418|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|SBGroupAttributeDescList|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the attribute descriptor for the flash group. 

## ○ **Command Details** 

When the parameter1 (SBGroupID, subsection 7.6) is specified, the data for the specified flash is transferred.  When the parameter1 (SBGroupID, subsection 7.6) is not specified or set to zero, the data for all flash are transferred. 

When the parameter2 (SBGroupAttrID) is specified, the data for the specified SBGroupAttribute (subsection 6.7.2) is transferred.  When the parameter2 (SBGroupAttrID) is not specified, the data for all SBGroupAttribute are transferred. 

The data set of SBGroupAttributeList is shown below. 

|Field|DataSize|DataType or DataSet|Description|
|---|---|---|---|
|NumberOfElements<br>Element1 SBGroupID<br>Element1<br>SBAttributeDescList<br>Element2 SBGroupID<br>Element2<br>SBAttributeDescList<br>ElementN<br>SBGroupID<br>ElementN<br>SBAttributeDescList|4|UINT32|ThenumberofSBGroupID inthelist.|
||4|SBGroupID|SBGroupID for element1.|
||DTS|SBAttributeDescList<br>(subsection9.11)|Attribute descriptor for the element1<br>flash.|
||4|SBGroupID|SBGroupID for element2.|
||DTS|SBAttributeDescList|Attribute descriptor for the element2<br>flash.|
|||…||
||4|SBGroupID|SBGroupID for element N.|
||DTS|SBAttributeDescList|Attribute descriptor for the element N<br>flash.|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|[SBGroupID]|
|Parameter2|[SBGroupAttrID]|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Parameter|Invalid SBGroupID is specified.|
||Invalid SBGroupAttrID is specified.|



Do Not Copy 

124/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.54 GetSBGroupAttrValue** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9419|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|SBGroupAttributeList|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode obtains the current attribute value for the flash group. 

## ○ **Command Details** 

When the parameter1 (SBGroupID, subsection 7.6) is specified, the data for the specified flash group is transferred.  When the parameter1 (SBGroupID, subsection 7.6) is not specified or set to zero, the data for all flash group are transferred. 

When the parameter2 (SBGroupAttrID) is specified, the data for the specified SBGroupAttribute (subsection 6.7.2) is transferred.  When the parameter2 (SBGroupAttrID) is not specified, the data for all SBGroupAttribute are transferred. 

## The data set of SBGroupAttributeList is shown below. 

|Field|DataSize|DataType or DataSet|Description|
|---|---|---|---|
|NumberOfElements|4|UINT32|ThenumberofSBGroupID inthelist.|
|Element1 SBGroupID|4|SBGroupID|SBGroupID for element1.|
|Element1<br>SBAttributeList|DTS|SBAttributeList<br>(subsection9.13)|SBAttributeList for element1.|
|Element2 SBGroupID|4|SBGroupID|SBGroupID for element2.|
|Element2<br>SBAttributeList|DTS|SBAttributeList|SBAttributeList for element2.|
|||…||
|ElementNSBGroupID|4|SBGroupID|SBGroupID forelementN.|
|ElementN<br>SBAttributeList|DTS|SBAttributeList|SBAttributeList for element N.|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|[SBGroupID]|
|Parameter2|[SBGroupAttrID]|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Parameter|Invalid SBGroupID is specified.|
||Invalid SBGroupAttrID is specified.|



Do Not Copy 

125/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.55 SetSBGroupAttrValue** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x941A|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|SBGroupAttributeList|
|Data direction|From host to camera|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode updates the current attribute value for the flash group. 

## ○ **Command Details** 

## The data set of SBGroupAttributeList is shown below. 

|Field|DataSize|DataType or DataSet|Description|
|---|---|---|---|
|NumberOfElements|4|UINT32|The number of SBGroupID in the list.|
|Element1 SBGroupID|4|SBGroupID|SBGroupID for element1.|
|Element1<br>SBAttributeList|DTS|SBAttributeList<br>(subsection 9.13)|SBAttributeList for element1.|
|Element2 SBGroupID|4|SBGroupID|SBGroupID for element2.|
|Element2<br>SBAttributeList|DTS|SBAttributeList|SBAttributeList for element2.|
|||…||
|ElementN SBGroupID|4|SBGroupID|SBGroupID for element N.|
|ElementN<br>SBAttributeList|DTS|SBAttributeList|SBAttributeList for element N.|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|None|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session isnot started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|Invalid_Parameter|Invalid SBHandle is specified.|
||Invalid SBAttrID is specified.|
|Invalid_SBAttribute_Value|The specified attribute value is not supported.|
|Access_Denied|An operation is denied depending on the status of the camera.|
||The specified SBAttributeCode is not permitted for setting.|
|Device_Busy|The shooting operation or the AF operation is being performed when<br>starting this command.|



Do Not Copy 

126/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.56 TestFlash** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x941B|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|None|
|Data direction|-|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode makes the flash fire for testing. 

## ○ **Command Details** 

The parameter1 (Flash mode) should be set to the flash testing. 

When the parameter1 is set to the flash testing: 

The flash specified by the parameter2 (SBHandle, subsection 7.5) fires.  When the parameter2 is set to zero, all flashes fire. 

- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|Flash mode (fixed to zero)|
|Parameter2|SBHandle|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Parameter|Invalid flash mode is specified.<br>Invalid SBHandleis specified.|
|Access_Denied|The specified flash cannot be operated.|



Do Not Copy 

127/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.57 GetObjectPropsSupported** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9801|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ObjectPropCodeArray|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode acquires an array of codes of the object property supported by the camera. 

## ○ **Command Details** 

The camera sends the Array of the property corresponding to ObjectFormatCode specified by Parameter1. 

The format of ObjectPropCodeArray sent by the camera is shown below. Each field data is stored in the little endian format. 

For the supported ObjectPropCode, refer to subsection 6.6. 

|Field|Size (Byte)|Data|
|---|---|---|
|NumElement|4|The element of the array is N (N means<br>thenumberofobjects).|
|ArrayEntry [0]|2|ObjectPropCode [0]|
|ArrayEntry [1]|2|ObjectPropCode [1]|
|ArrayEntry [2]|2|ObjectPropCode [2]|
||-|--|
|ArrayEntry [N - 1]|2|ObjectPropCode [N - 1]|



The camera supports the following ObjectFormatCodes only. 

|PropertyValue|ObjectFormat|
|---|---|
|0x3000|Undefined|
|0x3001|Association|
|0x300D|MOV<br>Apple QuickTimeVideoFormat (H.264/AVC)|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x380D|TIFF (RGB)|
|0xB982|MP4 Container|



## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectFormatCode|
|Parameter2|None|
|Parameter3|None|



## ○ **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|Anunsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionIDspecified by thehost.|
|Incomplete_Transfer|The data block transmission failed.|
|ObjectProp_Not_Supported|The specified ObjectFormatCodeisnot supported.|



Do Not Copy 

128/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.58 GetObjectPropDesc** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9802|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ObjectPropDesc data set|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode returns the ObjectPropDesc data set corresponding to the specified ObjectPropCode and ObjectFormatCode. 

## ○ **Command Details** 

For the supported ObjectPropCodes, refer to subsection 6.6. 

- **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectPropCode|
|Parameter2|ObjectFormatCode|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normal termination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer|The data block transmission failed.|
|ObjectProp_Not_Supported|The specified ObjectPropCodeisnot supported.|
||The specified ObjectFormatCode is not supported.|



Do Not Copy 

129/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.59 GetObjectPropValue** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9803|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ObjectPropValue|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode returns the current value corresponding to the specified ObjectPropCode. 

## ○ **Command Details** 

The camera sends the object property information specified by Parameter2 to the object corresponding to the ObjectHandle specified by Parameter1. 

For the supported ObjectPropCode and the details of ObjectPropValue, refer to subsection 6.6. 

## ○ **Operation Parameter** 

|Operation Parameter|Details|
|---|---|
|Parameter1|ObjectHandle|
|Parameter2|ObjectPropCode|
|Parameter3|None|



- **Response Code** 

|Response Code|Description|
|---|---|
|OK|Normaltermination|
|Parameter_Not_Supported|An unsupported parameter is specified.|
|Session_Not_Open|The session is not started.|
|Invalid_TransactionID|The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Invalid_Object_Handle|An object corresponding to the specified ObjectHandle does not exist,<br>or itindicates anobjectinthe SDRAM.|
|Incomplete_Transfer|The data block transmission failed.|
|Access_Denied|Themovieis playing.|
|ObjectProp_Not_Supported|The specified ObjectPropCode is not supported.|



Do Not Copy 

130/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.2.2.60 GetObjectPropList** 

- **Command Specifications** 

|**Command Specifications**||
|---|---|
|Operation Code|0x9805|
|Operation Parameter|Referto Operation Parameter inthis subsection.|
|Data|ObjectPropList data set|
|Data direction|Fromcamera tohost|
|Response Code|Refer to Response Code in this subsection.|
|Response Parameter|None|



## ○ **Command Outline** 

The operation by this OperationCode returns the ObjectPropList data set. 

## ○ **Command Details** 

The camera returns the ObjectPropList data set for the object corresponding to the ObjectHandle specified by Parameter1 and the ObjectPropCode (object property) specified by Parameter3.  The target can be identified by specifying the optional Parameter2, Parameter4, and Parameter5. 

For the supported ObjectPropCode and the details of ObjectPropValue, refer to subsection 6.6. 

|Operation Parameter|Value|Details|
|---|---|---|
|Parameter1|0x00000000|The objects directly under the root should be the targets.|
||ObjectHandle|The object matching with the specified object handle should be<br>the target.|
||0xFFFFFFFF|All the objects should be the targets.|
|Parameter2<br>(Optional)|0x00000000|Parameter2 is not specified.<br>The objects with all the object formats should be the targets.|
||ObjectFormatCode|The object with the specified format should be the target.|
|Parameter3|0x00000000|All the objects with the group code specified by Parameter4<br>should be the targets.|
||ObjectPropCode|The object with the specified property should be the target.|
||0xFFFFFFFF|All the objects without the group code of 0xFFFFFFFF should<br>be the targets.|
|Parameter4<br>(Optional)|ObjectPropGroupCode|The object with the specified group code should be the target.<br>*Thisis used onlywhen Parameter3is set to 0x00000000.|
|Parameter5<br>(Optional)|No value *1|Only the object specified by Parameter1 should be the target.<br>If Parameter1 is not specified (0x00000000), the camera<br>returns an empty ObjectPropList data set.|
||0x00000000||
||Depth|All the objects from the objects specified by Parameter1 to the<br>depth specified by Parameter5 should be the targets.|
||0xFFFFFFFF|All the objects included in the folder hierarchy of the object<br>specified by Parameter1 should be the targets.<br>If an object of the file is specified in Parameter1, however, only<br>the object specified byParameter1should be the target.|



*1 This is the case that ObjectHandle is specified in Parameter1.  When Parameter1 is set to 0x00000000, all the objects should be the targets. 

Do Not Copy 

131/484 

**Confidential** 

**Nikon Corporation** 

## **Confidential** 

The format of ObjectPropList sent by the camera is shown below. 

|Field name|Field order|Size（Byte）|Datatype|Description|
|---|---|---|---|---|
|NumberOfElements|1|4|UINT32|Number of properties (N)<br>The number of property fields is four times the<br>number of properties.|
|Element1ObjectHandle|2|4|ObjectHandle|ObjectHandle of the object to which Property 1<br>is applied|
|Element1PropertyCode|3|2|Datacode|Datacode that specifies the ObjectPropDesc<br>describingProperty1|
|Element1Datatype|4|2|Datacode|Specifies DatatypeCode of Property 1.|
|Element1Value|5|DTS|DTS|Value of Property1|
|Element2ObjectHandle|6|4|ObjectHandle|ObjectHandle of the object to which Property 2<br>is applied|
|Element2PropertyCode|7|2|Datacode|Datacode that specifies the ObjectPropDesc<br>describing Property 2|
|Element2Datatype|8|2|Datacode|Specifies DatatypeCode of Property 2.|
|Element2Value|9|DTS|DTS|Value of Property2|
||||・・・||
|ElementNObjectHandle|N x 4 - 2|4|ObjectHandle|ObjectHandle of the object to which Property N<br>is applied|
|ElementNPropertyCode|N x 4 - 1|2|Datacode|Datacode that specifies the ObjectPropDesc<br>describing Property N|
|ElementNDatatype|N x 4|2|Datacode|Specifies DatatypeCode of Property N.|
|ElementNValue|N x 4+1|DTS|DTS|Value of Property N|



## ○ **Operation Parameter** 

|Operation Parameter|Details|Details|
|---|---|---|
|Parameter1|ObjectHandle||
|Parameter2|[ObjectFormatCode]||
|Parameter3|ObjectPropCode||
|Parameter4|[ObjectPropGroupCode]||
|Parameter5|[Depth]||
|**Response Code**|||
|Response Code||Description|
|OK||Normal termination|
|Parameter_Not_Supported||An unsupported parameter is specified.|
|Session_Not_Open||The session is not started.|
|Invalid_TransactionID||The TransactionID retained by the camera differs from the<br>TransactionID specified by the host.|
|Incomplete_Transfer||The data block transmission failed.|
|Invalid_Object_Handle||An object corresponding to the specified ObjectHandle does<br>not exist, or itindicates anobjectinthe SDRAM.|
|Store_Not_Available||The card is being initialized.|
|||The card does not exist.|
|||The batteryis exhausted.|
|Access_Denied||The movie is playing.|
|Specification_By_Format_Unsupported||The specified ObjectFormatCodeisnot supported.|
|Invalid_ObjectPropCode||The specified ObjectPropCode is not supported.|



## ○ **Response Code** 

Do Not Copy 

132/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3 Response Code** 

The camera returns the response for the processing in the response phase to the command sent from the host to the camera in the command phase.  The ResponseCode shows the contents of the response.  The relationship between the ResponseCode and the OperationCode sent in the command phase is as shown in subsection 6.2. 

The ResponseCodes supported by the camera are shown below. 

|Response Code|Description|Reference<br>item|
|---|---|---|
|0x2001|OK|6.3.1.1|
|0x2002|General_Error|6.3.1.2|
|0x2003|Session_Not_Open|6.3.1.3|
|0x2004|Invalid_TransactionID|6.3.1.4|
|0x2005|Operation_Not_Supported|6.3.1.5|
|0x2006|Parameter_Not_Supported|6.3.1.6|
|0x2007|Incomplete_Transfer|6.3.1.7|
|0x2008|Invalid_StorageID|6.3.1.8|
|0x2009|Invalid_Object_Handle|6.3.1.9|
|0x200A|DeviceProp_Not_Supported|6.3.1.10|
|0x200B|Invalid_ObjectFormatCode|6.3.1.11|
|0x200C|Store_Full|6.3.1.12|
|0x200D|Object_Write_Protect|6.3.1.13|
|0x200E|Store_Read_Only|6.3.1.14|
|0x200F|Access_Denied|6.3.1.15|
|0x2010|No_Thumbnail_Present|6.3.1.16|
|0x2012|Partial_Deletion|6.3.1.17|
|0x2013|Store_Not_Available|6.3.1.18|
|0x2014|Specification_By_Format_Unsupported|6.3.1.19|
|0x2015|No_Valid_ObjectInfo|6.3.1.20|
|0x2019|Device_Busy|6.3.1.21|
|0x201A|Invalid_Parent_Object|6.3.1.22|
|0x201B|Invalid_DeviceProp_Format|6.3.1.23|
|0x201C|Invalid_DeviceProp_Value|6.3.1.24|
|0x201D|Invalid_Parameter|6.3.1.25|
|0x201E|Session_Already_Open|6.3.1.26|
|0x201F|Transaction_Cancelled|6.3.1.27|
|0x2020|Specification_of_Destination_Unsupported|6.3.1.28|
|0xA001|Hardware_Error|6.3.2.1|
|0xA002|Out_of_Focus|6.3.2.2|
|0xA003|Change_CameraMode_Failed|6.3.2.3|
|0xA004|Invalid_Status|6.3.2.4|
|0xA006|Wb_Preset_Error|6.3.2.5|
|0xA007|Dust_Reference_Error|6.3.2.6|
|0xA008|Shutter_Speed_Bulb|6.3.2.7|
|0xA00A|CameraMode_Not_Adjust_Fnumber|6.3.2.8|
|0xA00B|Not_LiveView|6.3.2.9|
|0xA00C|MfDrive_Step_End|6.3.2.10|
|0xA00E|MfDrive_Step_Insufficiency|6.3.2.11|
|0xA00F|No_FullHD_Present|6.3.2.12|
|0xA021|Store_Error|6.3.2.13|
|0xA022|Store_Unformatted|6.3.2.14|
|0xA200|Bulb_Release_Busy|6.3.2.15|
|0xA201|Silent_Release_Busy|6.3.2.16|
|0xA202|MovieFrame_Release_Busy|6.3.2.17|
|0xA204|Shutter_Speed_Time|6.3.2.18|
|0xA209|Invalid_SBAttribute_Value|6.3.2.19|
|0xA801|Invalid_ObjectPropCode|6.3.2.20|
|0xA802|Invalid_ObjectProp_Format|6.3.2.21|
|0xA80A|ObjectProp_Not_Supported|6.3.2.22|



Do Not Copy 

133/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3.1 Standard** 

## **6.3.1.1** 

## **OK** 

- **Response Specifications** 

Response Code 0x2001 

## ○ **Response Outline** 

Indicates that the processing has been terminated normally. 

## **6.3.1.2 General_Error** 

- **Response Specifications** 

Response Code 0x2002 

## ○ **Response Outline** 

Indicates that the processing cannot be terminated normally for some reason. 

## **6.3.1.3 Session_Not_Open** 

- **Response Specifications** 

Response Code 0x2003 

## ○ **Response Outline** 

Indicates that the session is not started. 

## **6.3.1.4 Invalid_TransactionID** 

- **Response Specifications** 

Response Code 0x2004 

## ○ **Response Outline** 

Indicates that the TransactionID retained by the camera differs from the TransactionID specified by the host. 

## **6.3.1.5 Operation_Not_Supported** 

## ○ **Response Specifications** 

Response Code 0x2005 

## ○ **Response Outline** 

Indicates that an OperationCode that is not passed by the DeviceInfo data set is specified. 

## **6.3.1.6 Parameter_Not_Supported** 

- **Response Specifications** 

Response Code 0x2006 

- **Response Outline** 

Indicates that the specification of a parameter is inappropriate for the requested operation. 

Do Not Copy 

134/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3.1.7 Incomplete_Transfer** 

- **Response Specifications** 

Response Code 0x2007 

- **Response Outline** 

Indicates that the transmission/reception of the data block fails. 

When the file access fails in the camera body, the camera may return this response. 

## **6.3.1.8 Invalid_StorageID** 

- **Response Specifications** 

Response Code 0x2008 

- **Response Outline** 

Indicates that a StorageID that differs from the StorageID sent by the camera is specified. 

## **6.3.1.9 Invalid_Object_Handle** 

- **Response Specifications** 

Response Code 0x2009 

- **Response Outline** 

Indicates that an invalid object handle is specified or the target object does not exist. 

## **6.3.1.10 DeviceProp_Not_Supported** 

- **Response Specifications** 

Response Code 0x200A 

- **Response Outline** 

Indicates that a DevicePropCode that is not passed by the DeviceInfo data set is specified. 

## **6.3.1.11 Invalid_ObjectFormatCode** 

- **Response Specifications** 

Response Code 0x200B 

- **Response Outline** 

Indicates that the specified ObjectFormatCode is not supported. 

It is also used to indicate that the contents specified in the ObjectCompressedSize field of ObjectInfo are not supported with the SendObjectInfo command. 

## **6.3.1.12 Store_Full** 

- **Response Specifications** 

Response Code 0x200C 

- **Response Outline** 

Indicates that the object cannot be received with the size of the buffer prepared by the camera with the SendObjectInfo command. 

Do Not Copy 

135/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3.1.13 Object_Write_Protect** 

- **Response Specifications** 

Response Code 0x200D 

- **Response Outline** 

Indicates that the target object is protected. 

## **6.3.1.14 Store_Read_Only** 

- **Response Specifications** 

Response Code 0x200E 

- **Response Outline** 

Indicates that a StorageID of the card is specified with the SendObjectInfo command. The camera does not support the writing to the card from the host. 

## **6.3.1.15 Access_Denied** 

## ○ **Response Specifications** 

Response Code 0x200F 

- **Response Outline** 

Indicates that the operation is denied because of the camera status. This means that the operation will be denied unless the camera status is changed. It is not an event that means the busy status. 

## **6.3.1.16 No_Thumbnail_Present** 

- **Response Specifications** 

Response Code 0x2010 

- **Response Outline** 

Indicates that the target object does not have a thumbnail. 

## **6.3.1.17 Partial_Deletion** 

- **Response Specifications** 

Response Code 0x2012 

## ○ **Response Outline** 

Indicates that although the deletion of two or more objects is commanded, only a part of those are deleted. 

It may occur when a part of the target objects are protected. 

Do Not Copy 

136/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3.1.18 Store_Not_Available** 

- **Response Specifications** 

Response Code 0x2013 

## ○ **Response Outline** 

Indicates that the card cannot be accessed because the card is being initialized, the card does not exist, or the battery is exhausted. 

## **6.3.1.19 Specification_By_Format_Unsupported** 

- **Response Specifications** 

Response Code 0x2014 

- **Response Outline** 

Indicates that the specified ObjectFormatCode is not supported. 

## **6.3.1.20 No_Valid_ObjectInfo** 

- **Response Specifications** 

Response Code 0x2015 

## ○ **Response Outline** 

Indicates that the SendObject command is received before the SendObjectInfo command is accepted. 

## **6.3.1.21 Device_Busy** 

- **Response Specifications** 

Response Code 0x2019 

- **Response Outline** 

Indicates that the camera is in the busy status. 

## **6.3.1.22 Invalid_Parent_Object** 

- **Response Specifications** 

Response Code 0x201A 

## ○ **Response Outline** 

Indicates that an ObjectHandle other than that indicating a directory is specified for a parameter with which an ObjectHandle of the directory should be specified. 

It indicates that the specified directory does not exist. 

Do Not Copy 

137/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3.1.23 Invalid_DeviceProp_Format** 

- **Response Specifications** 

Response Code 0x201B 

## ○ **Response Outline** 

Indicates that the size or the format of the DevicePropDesc data set is inappropriate. 

## **6.3.1.24 Invalid_DeviceProp_Value** 

- **Response Specifications** 

Response Code 0x201C 

## ○ **Response Outline** 

Indicates that the specified DevicePropValue is not supported. 

## **6.3.1.25 Invalid_Parameter** 

- **Response Specifications** 

Response Code 0x201D 

- **Response Outline** 

Indicates that the specified parameter is out of the specifications. 

## **6.3.1.26 Session_Already_Open** 

- **Response Specifications** 

Response Code 0x201E 

- **Response Outline** 

Indicates that the OpenSession operation is specified with a session already started. The camera supports only one session. 

## **6.3.1.27 Transaction _Cancelled** 

- **Response Specifications** 

Response Code 0x201F 

- **Response Outline** 

Indicates that the transfer was cancelled. 

## **6.3.1.28 Specification_of_Destination_Unsupported** 

- **Response Specifications** 

Response Code 0x2020 

## ○ **Response Outline** 

Indicates that the recording destination specified by the SendObjectInfo command is not supported. 

Do Not Copy 

138/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3.2 Vendor** 

## **6.3.2.1 Hardware_Error** 

- **Response Specifications** 

Response Code 0xA001 

## ○ **Response Outline** 

Indicates that any error that prevents the camera from operating has occurred in the camera body. 

## **6.3.2.2 Out_of_Focus** 

- **Response Specifications** 

Response Code 0xA002 

## ○ **Response Outline** 

Indicates that the AF operation is terminated with the non-focused status. 

## **6.3.2.3 Change_CameraMode_Failed** 

- **Response Specifications** 

Response Code 0xA003 

## ○ **Response Outline** 

Indicates that the switching between the PC camera mode and the remote mode failed. 

## **6.3.2.4 Invalid_Status** 

- **Response Specifications** 

Response Code 0xA004 

- **Response Outline** 

Indicates that the operation is invalid depending on the status of the camera. 

## **6.3.2.5 Wb_Preset_Error** 

- **Response Specifications** 

Response Code 0xA006 

- **Response Outline** 

Indicates that the preset measurement release failed. 

## **6.3.2.6 Dust_Reference_Error** 

- **Response Specifications** 

Response Code 0xA007 

- **Response Outline** 

Indicates that the dust reference image release failed. 

Do Not Copy 

139/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3.2.7 Shutter_Speed_Bulb** 

- **Response Specifications** 

Response Code 0xA008 

- **Response Outline** 

Indicates that the shutter speed is Bulb. 

## **6.3.2.8 CameraMode_Not_Adjust_Fnumber** 

- **Response Specifications** 

Response Code 0xA00A 

## ○ **Response Outline** 

Indicates that the aperture value is set to “F--". 

## **6.3.2.9 Not_LiveView** 

- **Response Specifications** 

Response Code 0xA00B 

- **Response Outline** 

Indicates that the camera is not in the live view condition. 

## **6.3.2.10 MfDrive_Step_End** 

- **Response Specifications** 

Response Code 0xA00C 

- **Response Outline** 

Indicates that the MF driving reaches the termination. 

## **6.3.2.11 MfDrive_Step_ Insufficiency** 

- **Response Specifications** 

Response Code 0xA00E 

- **Response Outline** 

Indicates that the driving amount is insufficient. 

## **6.3.2.12 No_FullHD_Present** 

- **Response Specifications** 

Response Code 0xA00F 

- **Response Outline** 

Indicates that the target object does not include FullHD image data. 

Do Not Copy 

140/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3.2.13 Store_Error** 

- **Response Specifications** 

Response Code 0xA021 

## ○ **Response Outline** 

Indicates that a damaged card is included in the inserted cards. 

## **6.3.2.14 Store_Unformatted** 

- **Response Specifications** 

Response Code 0xA022 

- **Response Outline** 

Indicates that an unformatted card is included in the inserted cards. 

## **6.3.2.15 Bulb_Release_Busy** 

- **Response Specifications** 

Response Code 0xA200 

- **Response Outline** 

Indicates that bulb shooting is being performed. 

## **6.3.2.16 Silent_Release_Busy** 

- **Response Specifications** 

Response Code 0xA201 

- **Response Outline** 

Indicates that silent shooting is being performed. 

## **6.3.2.17 MovieFrame_Release_Busy** 

## ○ **Response Specifications** 

Response Code 0xA202 

## ○ **Response Outline** 

Indicates that the still image shooting is being performed during movie recording. 

## **6.3.2.18 Shutter_Speed_Time** 

- **Response Specifications** 

Response Code 0xA204 

## ○ **Response Outline** 

Indicates that the shutter speed is Time. 

Do Not Copy 

141/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.3.2.19 Invalid_SBAttribute_Value** 

- **Response Specifications** 

Response Code 0xA209 

## ○ **Response Outline** 

Indicates that the specified attribute value is not supported. 

## **6.3.2.20 Invalid_ObjectPropCode** 

- **Response Specifications** 

Response Code 0xA801 

- **Response Outline** 

Indicates that the specified ObjectPropCode is not supported. 

## **6.3.2.21 Invalid_ObjectProp_Format** 

- **Response Specifications** 

Response Code 0xA802 

## ○ **Response Outline** 

Indicates that the size or the type of the specified ObjectProp is not supported. 

## **6.3.2.22 ObjectProp_Not_Supported** 

- **Response Specifications** 

Response Code 0xA80A 

- **Response Outline** 

Indicates that the specified ObjectPropCode is valid but the camera doesn’t support it. 

Do Not Copy 

142/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.4 Event Code** 

The EventCodes are used when an event is passed asynchronously from the camera to the host. 

Following chart describes the EventCodes supported by the camera and whether event sending by command from host or by interrupt transfer is permitted. 

|Event<br>Code|Description|Reference|Interrupt<br>transfer|GetEvent<br>command|GetEventEx<br>command|
|---|---|---|---|---|---|
|0x4001|CancelTransaction|6.4.1.1|`✓`|`✓`|`✓`|
|0x4002|ObjectAdded|6.4.1.2|`✓`|`✓`|`✓`|
|0x4003|ObjectRemoved|6.4.1.3|`✓`|`✓`|`✓`|
|0x4004|StoreAdded|6.4.1.4|`✓`|`✓`|`✓`|
|0x4005|StoreRemoved|6.4.1.5|`✓`|`✓`|`✓`|
|0x4006|DevicePropChanged|6.4.1.6|`✓`|`✓`|`✓`|
|0x4007|ObjectInfoChanged|6.4.1.7|`✓`|`✓`|`✓`|
|0x4008|DeviceInfoChanged|6.4.1.8|`✓`|`✓`|`✓`|
|0x4009|RequestObjectTransfer|6.4.1.9|`✓`|`✓`|`✓`|
|0x400A|StoreFull|6.4.1.10|`✓`|`✓`|`✓`|
|0x400C|StorageInfoChanged|6.4.1.11|`✓`|`✓`|`✓`|
|0x400D|CaptureComplete|6.4.1.12|`✓`|`✓`|`✓`|
|0xC101|ObjectAddedInSdram|6.4.2.1|-|`✓`|`✓`|
|0xC102|CaptureCompleteRecInSdram|6.4.2.2|-|`✓`|`✓`|
|0xC105|MovieRecordInterrupted|6.4.2.5|-|-|`✓`|
|0xC108|MovieRecordComplete|6.4.2.4|-|`✓`|`✓`|
|0xC10A|MovieRecordStarted|6.4.2.3|-|`✓`|`✓`|
|0xC10B|PictureControlAdjustChanged|6.4.2.6|-|-|`✓`|
|0xC10C|LiveViewStateChanged|6.4.2.7|-|`✓`|`✓`|
|0xC10D|PixelMappingComplete|6.4.2.8|-|`✓`|`✓`|
|0xC10E|ManualSettingLensDataChanged|6.4.2.9|-|`✓`|`✓`|
|0xC120|SBAdded|6.4.2.10|-|`✓`|`✓`|
|0xC121|SBRemoved|6.4.2.11|-|`✓`|`✓`|
|0xC122|SBAttrChanged|6.4.2.12|-|-|`✓`|
|0xC123|SBGroupAttrChanged|6.4.2.13|-|-|`✓`|



Do Not Copy 

143/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.4.1  Standard** 

## **6.4.1.1 CancelTransaction** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x4001|
|EventParameter1|None|



## ○ **Event Outline** 

It is used to inform the host that the processing is canceled.  However, it is not used in the camera. 

## **6.4.1.2 ObjectAdded** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x4002|
|Event Parameter1|ObjectHandle|



- **Event Outline** 

It is used to inform the host that a new object is added to the card. 

## **6.4.1.3 ObjectRemoved** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x4003|
|EventParameter1|ObjectHandle|



- **Event Outline** 

   - It is used to inform the host that a specific object in the card is deleted. 

## **6.4.1.4 StoreAdded** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x4004|
|EventParameter1|StorageID|



- **Event Outline** 

It is used to inform the host that the card is inserted in the slot in which the card has not been inserted yet. 

The StorageID corresponding to the slot in which the card is inserted is passed as an EventParameter. 

## **6.4.1.5 StoreRemoved** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x4005|
|Event Parameter1|StorageID|



- **Event Outline** 

It is used to inform the host that the card is ejected from the slot in which the card has been inserted. 

The StorageID corresponding to the slot in which the card has been inserted is passed as an EventParameter. 

It is also used when the card is formatted to inform the host that the card information is invalid. When the formatting is completed, StoreAdded is used to inform the host that the card information is 

Do Not Copy 

144/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

valid. 

## **6.4.1.6 DevicePropChanged** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x4006|
|EventParameter1|PropertyCode|



## ○ **Event Outline** 

It is used to inform the host that the setting value of the camera is changed. 

The setting value to be passed is that of DevicePropCode defined in subsection 6.5. 

If the setting value of the camera is changed by the SetDevicePropValue command from the host, this event is not passed. 

When the InterruptIN transfer is used, this event is passed only for the standard property. When the GetEventEx command is used, this event is passed for all the properties. 

## **6.4.1.7 ObjectInfoChanged** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x4007|
|Event Parameter1|ObjectHandle|



## ○ **Event Outline** 

It is used to inform the host that the ObjectInfo data set corresponding to a specific object in the card has been changed. 

## **6.4.1.8 DeviceInfoChanged** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x4008|
|EventParameter1|None|



- **Event Outline** 

It is used to inform the host that the device function is changed. 

## **6.4.1.9 RequestObjectTransfer** 

## ○ **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x4009|
|EventParameter1|ObjectHandle|



- **Event Outline** 

It is used to request the GetObject operation for the ObjectHandle specified by the parameter. 

Do Not Copy 

145/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.4.1.10 StoreFull** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x400A|
|EventParameter1|StorageID|



## ○ **Event Outline** 

It is used to inform the host that the card corresponding to the StorageID becomes full. This event is passed when the card becomes full by operating the shutter-release button of the camera or by recording the movie. 

## **6.4.1.11 StorageInfoChanged** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x400C|
|EventParameter1|StorageID|



## ○ **Event Outline** 

It is used to inform the host that the free area in the card corresponding to the StorageID is changed. 

This event is passed when the setting value of the image size or that of the image quality mode is changed. 

## **6.4.1.12 CaptureComplete** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0x400D|
|Event Parameter1|TransactionID|



## ○ **Event Outline** 

It is used to inform the host that the release operation started by the InitiateCapture command or the InitiateCaptureRecInMedia command is completed. 

Do Not Copy 

146/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.4.2  Vendor** 

## **6.4.2.1 ObjectAddedInSdram** 

- **Event Specifications** 

Event Code 0xC101 Event Parameter1 ObjectHandle 

## ○ **Event Outline** 

It is used to inform the host that a new object is added to the SDRAM (transmission of the image data to the host becomes enabled). 

The ObjectHandle of the new object is passed as an EventParameter. 

If the USB cutting occurs with the image data of the recording destination SDRAM saved in the SDRAM and then it is reconnected, the event is passed again. 

## **6.4.2.2 CaptureCompleteRecInSdram** 

## ○ **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC102|
|EventParameter1|None|



## ○ **Event Outline** 

It is used to inform the host that all the image data acquired by the release operation started by the InitiateCaptureRecInSdram, the AfAndCaptureRecInSdram, or the InitiateCaptureRecInMedia command is sent to the host completely. 

Do Not Copy 

147/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.4.2.3 MovieRecordStarted** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC10A|
|EventParameter1|RecordKind|



- **Event Outline** 

It is used to inform the host that the movie recording has started on the camera. This event is not issued when the movie recording has started by using StartMovieRecord command. 

The recording method is sent as an EventParameter. 

|RecordKind|Recording method|
|---|---|
|0x00000000|Card|
|0x00000001|External recorder|
|0x00000002|Card and external recorder|



## **6.4.2.4 MovieRecordComplete** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC108|
|Event Parameter1|RecordKind|



- **Event Outline** 

It is used to inform the host that the movie recording is successfully completed. 

The recording method is sent as an EventParameter. 

|RecordKind|Recording method|
|---|---|
|0x00000000|Card|
|0x00000001|External recorder|
|0x00000002|Card and external recorder|



## **6.4.2.5 MovieRecordInterrupted** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC105|
|Event Parameter1|ErrorCode|
|Event Parameter2|RecordKind|



- **Event Outline** 

It is used to inform the host that the movie recording is interrupted. 

The interruption cause and the recording method are sent as EventParameter. 

|ErrorCode|Interruption cause|
|---|---|
|0x00000001|A certain error|
|0x00000002|Low-speed card error|
|||
|RecordKind|Interrupted recording method|
|0x00000000|Card|
|0x00000001|External recorder|
|0x00000002|Card and external recorder|



Do Not Copy 

148/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.4.2.6 PictureControlAdjustChanged** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC10B|
|Event Parameter1|PicCtrlItem (equivalent to the ActivePicCtrlItem property (subsection<br>6.5.13.1)|
|EventParameter2|ShootingMode|



## ○ **Event Outline** 

It is used to inform the host that any setting value of the picture control was changed, or any setting value of the custom picture control was changed, registerd, renamed or deleted. 

The changed menu (photo shooting menu or movie shooting menu) is set in Parameter 2. 

|ShootingMode|Menu|
|---|---|
|0x00000000|Photo shooting menu|
|0x00000001|Movie shooting menu|



## **6.4.2.7 LiveViewStateChanged** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC10C|
|EventParameter1|CameraLiveViewStatus|



- **Event Outline** 

It is used to inform the host that the state of live view has changed on the camera. 

|CameraLiveViewStatus|Description|
|---|---|
|0|OFF|
|1|ON|



## **6.4.2.8 PixelMappingComplete** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC10D|
|Event Parameter1|Result|



- **Event Outline** 

It is used to inform the host that pixel mapping initiated by the InitiatePixelMapping command is complete. 

|Code|Result|
|---|---|
|0x00000000|Failed|
|0x00000001|Completed|



Do Not Copy 

149/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.4.2.9 ManualSettingLensDataChanged** 

## ○ **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC10E|
|EventParameter1|LensNo|



## ○ **Event Outline** 

It is used to inform the host that the information of “Non-CPU lens data” in the setup menu has been changed. 

The lens No. of the changed lens is passed as an EventParameter. 

|LensNo|Description|
|---|---|
|Refer to ManualSettingLensNo property (subsection<br>6.5.5.1)|Lens No. of the changed lens|
|0xFFFFFFFF|All lenses (Not supported on this<br>camera)|



Do Not Copy 

150/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.4.2.10 SBAdded** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC120|
|EventParameter1|SBHandle|



## ○ **Event Outline** 

It is used to inform the host that the flash unit is newly attached to the camera. 

## **6.4.2.11 SBRemoved** 

- **Event Specifications** 

|**Event Specifications**||
|---|---|
|Event Code|0xC121|
|EventParameter1|SBHandle|



- **Event Outline** 

   - It is used to inform the host that the flash unit is detached from the camera. 

## **6.4.2.12 SBAttrChanged** 

- **Event Specifications** 

|Event Code|0xC122|
|---|---|
|Event Parameter1|SBHandle|
|EventParameter2|SBAttrID|



- **Event Outline** 

It is used to inform the host that the attributes of the flash unit have changed. 

This event is not issued when the attributes of the flash have changed by receiving SetSBAttrValue command from the host. 

## **6.4.2.13 SBGroupAttrChanged** 

- **Event Specifications** 

|Event Code|0xC123|
|---|---|
|EventParameter1|SBGroupID|
|Event Parameter2|SBGroupAttrID|



## ○ **Event Outline** 

It is used to inform the host that the attribute descriptor for the flash group or the current value has changed. 

This event is not issued when the attributes of the flash group have changed by receiving SetSBGroupAttrValue command from the host. 

If the SBWirelessMode property (subsection 6.5.9.7) is set to other than “Stand-alone flash” and the SBWirelessMultipleFlashMode property (subsection 6.5.9.8) is set to “Repeating”, SBGroupID of the master flash is used to inform the changes for the following flash group regardless of the value of the SBUsableGroup property (subsection 6.5.9.9). 

- ・SBGroupFlashLevel (subsection 6.7.2.4) 

- ・SBGroupRepeatCount (subsection 6.7.2.7) 

- ・SBGroupRepeatInterval (subsection 6.7.2.8) 

Do Not Copy 

151/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5 DevicePropCode** 

The camera has an attribute that can be changed as an option.  The change is made by operating the device property.  The property shows the device characteristics.  Each property has a corresponding DevicePropCode. 

When the setting value of each defined property is changed, the camera sends the DevicePropChanged event including the DevicePropCode in order to inform the host of the change. The camera sends the event as shown below. 

|No.|Description|
|---|---|
|1|The camera periodically (every 1 second) checks all the values of DeviceProperty.  When a<br>DeviceProperty whose value has changed since the last checking is detected, the camera sends<br>the DevicePropChanged event in order to inform the host of the change.  When detecting changes<br>in two or more DeviceProperties, the camera sends the DevicePropChanged event for all the<br>DeviceProperties in succession.|
|2|When the setting value of the DeviceProperty is changed by the SetDevicePropValue command,<br>the camera does not send the DevicePropChanged event including the changed DevicePropCode.<br>However, if any other DeviceProperty is changed under the influence of the change of the<br>DeviceProperty, the camera sends the DevicePropChanged event for the property.  For example,<br>if the aperture value is changed by the SetDevicePropValue command when shooting is performed<br>in the A mode (aperture priority), the camera changes the shutter speed automatically.  In this<br>case, the camera sends theDevicePropChanged eventforthe shutterspeed.|



The error response is made to GetDevicePropDesc, GetDevicePropValue, and SetDevicePropValue as shown below. 

|No.|Description|
|---|---|
|1|When either or both of getting/setting are invalid depending on the setting status of the camera for<br>each property, the response of the ResponseCode corresponding to the invalid status is made.|
|2|When setting is performed for the property that supports getting only, the Access_Denied error<br>response is made.|



Sometimes another event needs to be issued after the DevicePropChanged event depending on the type of the PropertyCode.  It is described in the explanation for each PropertyCode. 

The properties whose values cannot be set during live view or movie recording are described in the following table of DevicePropCodes instead of Response Code of each property.  If a value is set to a DevicePropertyCode that is not shown in the table, the Access_Denied response is made. 

Regarding the description of the shooting mode indicated by the ExposureProgramMode property such as property details and setting prohibition conditions, the condition also includes the case where the ExposureProgramMode property is the corresponding shooting mode in the user mode. 

## Example) 

Access_Denied ExposureProgramMode property is set to anything other than PSAM. 

In this case, Access_Denied returns when ExposureProgramMode property is set to U1/U2/U3 and UserMode property is set to anything other than PSAM. 

The DevicePropCodes supported by the camera are shown below. 

|Property<br>Code|Description|Reference|Live view<br>photography|Movie live<br>view|During<br>movie<br>recording|
|---|---|---|---|---|---|
|0x5001|BatteryLevel|6.5.1.1||||
|0x5003|ImageSize|6.5.1.2|`✓`|`✓`|`✓`|
|0x5004|CompressionSetting|6.5.1.3|`✓`|-|-|
|0x5005|WhiteBalance|6.5.1.4|`✓`|`✓`|`✓`|
|0x5007|Fnumber|6.5.1.5|`✓`|`✓`|`✓`|
|0x5008|FocalLength|6.5.1.6||||
|0x500A|FocusMode|6.5.1.7||||
|0x500B|ExposureMeteringMode|6.5.1.8|`✓`|`✓`|-|
|||||||



152/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

|0x500C|FlashMode|6.5.1.9|`✓`|-|-|
|---|---|---|---|---|---|
|0x500D|ExposureTime|6.5.1.10|`✓`|-|-|
|0x500E|ExposureProgramMode|6.5.1.11|`✓`|`✓`|-|
|0x500F|ExposureIndex|6.5.1.12|`✓`|`✓`|`✓`|
|0x5010|ExposureBiasCompensation|6.5.1.13|`✓`|`✓`|`✓`|
|0x5011|DateTime|6.5.1.14|`✓`|`✓`|-|
|0x5013|StillCaptureMode|6.5.1.15|`✓`|`✓`|`-`|
|0x5018|BurstNumber|6.5.1.16|`✓`|`✓`|`✓`|
|0x501E|Artist|6.5.1.17||||
|0x501F|Copyright|6.5.1.18||||
|0xD016|RawCompressionType|6.5.2.5|`✓`|`✓`|-|
|0xD017|WbTuneAuto|6.5.2.15|`✓`|`✓`|`✓`|
|0xD018|WbTuneIncandescent|6.5.2.20|`✓`|`✓`|`✓`|
|0xD019|WbTuneFluorescent|6.5.2.22|`✓`|`✓`|`✓`|
|0xD01A|WbTuneSunny|6.5.2.17|`✓`|`✓`|`✓`|
|0xD01B|WbTuneFlash|6.5.2.23|`✓`|`✓`|`✓`|
|0xD01C|WbTuneCloudy|6.5.2.18|`✓`|`✓`|`✓`|
|0xD01D|WbTuneShade|6.5.2.19|`✓`|`✓`|`✓`|
|0xD01E|WbColorTemp|6.5.2.24|`✓`|`✓`|`✓`|
|0xD01F|WbPresetDataNo|6.5.2.26|`✓`|`✓`|`✓`|
|0xD021|WbPresetDataComment1|6.5.2.27|`✓`|`✓`|-|
|0xD022|WbPresetDataComment2|6.5.2.28|`✓`|`✓`|-|
|0xD023|WbPresetDataComment3|6.5.2.29|`✓`|`✓`|-|
|0xD024|WbPresetDataComment4|6.5.2.30|`✓`|`✓`|-|
|0xD026|WbPresetDataValue1|6.5.2.33||||
|0xD027|WbPresetDataValue2|6.5.2.34||||
|0xD028|WbPresetDataValue3|6.5.2.35||||
|0xD029|WbPresetDataValue4|6.5.2.36||||
|0xD02E|FmmManualSetting|6.5.5.2|`✓`|`✓`|-|
|0xD02F|F0ManualSetting|6.5.5.3|`✓`|`✓`|-|
|0xD030|CaptureAreaCrop|6.5.2.3|`✓`|`✓`|-|
|0xD032|ColorSpace|6.5.2.51|`✓`|`✓`|-|
|0xD034|DecreaseFlicker|6.5.3.51|`✓`|`✓`|-|
|0xD038|WbPresetDataComment5|6.5.2.31|`✓`|`✓`|-|
|0xD039|WbPresetDataComment6|6.5.2.32|`✓`|`✓`|-|
|0xD03A|WbTunePreset5|6.5.2.43|`✓`|`✓`|`✓`|
|0xD03B|WbTunePreset6|6.5.2.44|`✓`|`✓`|`✓`|
|0xD03C|WbPresetProtect5|6.5.2.49|`✓`|`✓`|-|
|0xD03D|WbPresetProtect6|6.5.2.50|`✓`|`✓`|-|
|0xD03E|WbPresetDataValue5|6.5.2.37||||
|0xD03F|WbPresetDataValue6|6.5.2.38||||
|0xD046|AFStillLockOnAcross|6.5.4.3|`✓`|`✓`|-|
|0xD048|DynamicAFonAFC|6.5.4.1|`✓`|`✓`|-|
|0xD049|DynamicAFonAFS|6.5.4.2|`✓`|`✓`|-|
|0xD053|EnableCopyright|6.5.5.10|`✓`|`✓`|-|
|0xD054|ISOAutoControl|6.5.2.9|`✓`|`✓`|-|
|0xD056|ExposureEVStep|6.5.4.6|`✓`|`✓`|-|
|0xD059|CenterWeightedExRange|6.5.4.7|`✓`|`✓`|-|
|0xD05A|ExposureBaseCompMatrix|6.5.4.8|`✓`|`✓`|-|
|0xD05B|ExposureBaseCompCenter|6.5.4.9|`✓`|`✓`|-|
|0xD05C|ExposureBaseCompSpot|6.5.4.10|`✓`|`✓`|-|
|0xD05D|StillFocusMeteringMode|6.5.2.61|`✓`|`✓`|`-`|
|0xD061|StillFocusMode|6.5.2.60|`✓`|`✓`|-|
|0xD067|AngleLevel|6.5.7.20||||
|0xD068|CSpeedLow|6.5.4.12|`✓`|`✓`|-|
|0xD069|BurstMaxNumber|6.5.4.13|`✓`|`✓`|-|
|0xD06A|ExposureDelay|6.5.4.14|`✓`|`✓`|-|
|0xD06B|NoiseReduction|6.5.2.53|`✓`|`✓`|-|



Do Not Copy 

153/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

|0xD06C|NumberingMode|6.5.4.17|`✓`|`✓`|-|
|---|---|---|---|---|---|
|0xD070|NoiseReductionHiIso|6.5.2.54|`✓`|`✓`|-|
|0xD072|ArtistV|6.5.5.8|`✓`|`✓`|-|
|0xD073|CopyrightV|6.5.5.9|`✓`|`✓`|-|
|0xD074|FlashSyncSpeed|6.5.4.20|`✓`|`✓`|-|
|0xD075|FlashSlowSpeedLimit|6.5.4.21|`✓`|`✓`|-|
|0xD078|BracketingType|6.5.2.63|`✓`|`✓`|-|
|0xD079|SelectBracketChangeFactor|6.5.4.24|`✓`|`✓`|-|
|0xD07A|BracketingOrder|6.5.4.25|`✓`|`✓`|-|
|0xD07D|AngleLevelPitching|6.5.7.21||||
|0xD07E|AngleLevelYawing|6.5.7.22||||
|0xD08A|EnableShutter|6.5.5.14|`✓`|`✓`|-|
|0xD08D|EnableAFAreaPoint|6.5.4.4|`✓`|`✓`|-|
|0xD08F|ImageSensorCleaning|6.5.5.5|`✓`|`✓`|-|
|0xD090|CommentString|6.5.5.6|`✓`|`✓`|-|
|0xD091|EnableComment|6.5.5.7|`✓`|`✓`|-|
|0xD093|ManualSettingLensNo|6.5.5.1|`✓`|`✓`|-|
|0xD09C|RetractableLensWarning|6.5.10.9||||
|0xD0A0|MovieRecordScreenSize|6.5.3.3|`✓`|`✓`|-|
|0xD0A2|MovieRecordMicrophoneLevel|6.5.3.57|`✓`|`✓`|`✓`|
|0xD0A3|MovieRecordDestination|6.5.3.1|`✓`|`✓`|-|
|0xD0A4|MovieRecProhibitionCondition|6.5.7.25||||
|0xD0A7|MovieRecordQuality|6.5.3.4|`✓`|`✓`|-|
|0xD0A8|MovieRecordMicrophoneLevelValue|6.5.3.58|`✓`|`✓`|`✓`|
|0xD0AA|MovieWindNoiseReduction|6.5.3.61|`✓`|`✓`|`✓`|
|0xD0AC|MovieRecordingZone|6.5.3.60|`✓`|`✓`|`✓`|
|0xD0AD|MovieISOAutoControl|6.5.3.7|`✓`|`✓`|`✓`|
|0xD0AE|MovieISOAutoHighLimit|6.5.3.6|`✓`|`✓`|`✓`|
|0xD0AF|MovieFileType|6.5.3.5|`✓`|`✓`|-|
|0xD0B4|ExposureIndexEx|6.5.2.7|`✓`|`✓`|`✓`|
|0xD0B5|ISOControlSensitivity|6.5.7.14||||
|0xD0B6|RawImageSize|6.5.2.4|`✓`|`✓`|-|
|0xD0B7|FlickerReductionSetting|6.5.2.58|`✓`|`✓`|-|
|0xD0BA|DiffractionCompensation|6.5.2.56|`✓`|`✓`|-|
|0xD0BB|MovieLogOutput|6.5.7.27||||
|0xD0BC|MovieAutoDistortion|6.5.3.50|`✓`|`✓`|-|
|0xD0BE|RemainingExposureTime|6.5.7.12||||
|0xD0BF|MovieLogSetting|6.5.5.13|`✓`|`✓`|-|
|0xD0C0|EnableBracketing|6.5.8.1|`✓`|`✓`|-|
|0xD0C1|AEBracketingStep|6.5.8.2|`✓`|`✓`|-|
|0xD0C2|AEBracketingPattern|6.5.8.3|`✓`|`✓`|-|
|0xD0C3|AEBracketingCount|6.5.8.4||||
|0xD0C4|WBBracketingStep|6.5.8.5|`✓`|`✓`|-|
|0xD0C5|WBBracketingPattern|6.5.8.6|`✓`|`✓`|-|
|0xD0C6|ADLBracketingPattern|6.5.8.7|`✓`|`✓`|-|
|0xD0C7|ADLBracketingStep|6.5.8.8|`✓`|`✓`|-|
|0xD0CC|HDMIOutputDataDepth|6.5.5.12|`✓`|`✓`|-|
|0xD0CD|SaveFocusPosition|6.5.5.4|`✓`|`✓`|-|
|0xD0E0|LensID|6.5.10.4||||
|0xD0E1|LensSort|6.5.10.1||||
|0xD0E2|LensTypeF|6.5.10.3||||
|0xD0E3|LensFocalMin|6.5.10.5||||
|0xD0E4|LensFocalMax|6.5.10.6||||
|0xD0E5|LensApatureMin|6.5.10.7||||
|0xD0E6|LensApatureMax|6.5.10.8||||
|0xD0E7|LensTypeML|6.5.10.2|||-|
|0xD0F7|VignetteControl|6.5.2.55|`✓`|`✓`|-|
|0xD0F8|AutoDistortion|6.5.2.57|`✓`|`✓`|-|
|0xD0FC|UserMode|6.5.7.1||||



Do Not Copy 

154/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

|0xD100|ShutterSpeed|6.5.7.11|`✓`|-|-|
|---|---|---|---|---|---|
|0xD101|ExternalDC-IN|6.5.6.1||||
|0xD102|WarningStatus|6.5.7.23||||
|0xD104|AFLockStatus|6.5.7.9||||
|0xD105|AELockStatus|6.5.7.8||||
|0xD106|FVLockStatus|6.5.7.10||||
|0xD109|FlexibleProgram|6.5.7.13|`✓`|-|-|
|0xD10B|RecordingMedia|6.5.7.3|`✓`|`✓`|-|
|0xD10C|USBSpeed|6.5.11.1||||
|0xD10E|Orientation|6.5.7.2||||
|0xD112|TVLockSetting|6.5.4.26|`✓`|`✓`|-|
|0xD113|AVLockSetting|6.5.4.27|`✓`|`✓`|-|
|0xD118|ExposureCompFlashUsed|6.5.4.22|`✓`|`✓`|-|
|0xD120|ExternalSpeedLightExist|6.5.9.1||||
|0xD121|ExternalSpeedLightStatus|6.5.9.3||||
|0xD122|ExternalSpeedLightSort|6.5.9.2||||
|0xD124|FlashCompensation|6.5.9.5||||
|0xD125|NewExternalSpeedLightMode|6.5.9.4||||
|0xD126|InternalFlashCompensation|6.5.2.59|`✓`|-|-|
|0xD12D|ExternalSpeedLightMultiFlashMode|6.5.9.6||||
|0xD12E|ConnectionPath|6.5.11.2||||
|0xD130|HDRMode|6.5.2.64|`✓`|`✓`|-|
|0xD131|HDREv|6.5.2.65|`✓`|`✓`|-|
|0xD132|HDRSmoothing|6.5.2.66|`✓`|`✓`|-|
|0xD133|HDRSaveIndividualImages|6.5.2.67|`✓`|`✓`|-|
|0xD138|VibrationReduction|6.5.2.62|`✓`|`✓`|-|
|0xD141|WbAutoType|6.5.2.14|`✓`|`✓`|`✓`|
|0xD148|Slot2ImageSaveMode|6.5.2.2|`✓`|`✓`|-|
|0xD149|RawCompressionBitMode|6.5.2.6|`✓`|`✓`|-|
|0xD14E|Active-D-Lighting|6.5.2.52|`✓`|`✓`|-|
|0xD14F|WbFluorescentType|6.5.2.21|`✓`|`✓`|`✓`|
|0xD150|WbTuneColorTemp|6.5.2.25|`✓`|`✓`|`✓`|
|0xD152|WbTunePreset1|6.5.2.39|`✓`|`✓`|`✓`|
|0xD153|WbTunePreset2|6.5.2.40|`✓`|`✓`|`✓`|
|0xD154|WbTunePreset3|6.5.2.41|`✓`|`✓`|`✓`|
|0xD155|WbTunePreset4|6.5.2.42|`✓`|`✓`|`✓`|
|0xD158|WbPresetProtect1|6.5.2.45|`✓`|`✓`|-|
|0xD159|WbPresetProtect2|6.5.2.46|`✓`|`✓`|-|
|0xD15A|WbPresetProtect3|6.5.2.47|`✓`|`✓`|-|
|0xD15B|ActiveFolder|6.5.7.26||||
|0xD15C|WbPresetProtect4|6.5.2.48|`✓`|`✓`|-|
|0xD15E|WbTuneNatural|6.5.2.16|`✓`|`✓`|-|
|0xD164|ISOAutoShutterTime|6.5.2.12|`✓`|`✓`|-|
|0xD16A|ISOAutoSetting|6.5.2.8|`✓`|`✓`|-|
|0xD16E|ExtendedShutterSpeedsManual|6.5.4.16|`✓`|`✓`|-|
|0xD17A|LowLightAF|6.5.4.5|`✓`|`✓`|-|
|0xD17B|ApplyLiveViewSetting|6.5.4.18|`✓`|`✓`|-|
|0xD17C|MovieAfSpeed|6.5.4.29|`✓`|`✓`|-|
|0xD17D|MovieAfSpeedWhenToApply|6.5.4.30|`✓`|`✓`|-|
|0xD17E|MovieAfTrackingSensitivity|6.5.4.31|`✓`|`✓`|-|
|0xD183|ISOAutoHighLimit|6.5.2.10|`✓`|`✓`|-|
|0xD197|MovieReleaseButton|6.5.4.28|`✓`|`✓`|-|
|0xD199|FlashISOAutoHighLimit|6.5.2.11|`✓`|`✓`|-|
|0xD1A2|RemoteLiveViewStatus|6.5.12.1||||
|0xD1A4|LiveViewProhibitionCondition|6.5.12.7||||
|0xD1A6|LiveViewSelector|6.5.12.8|`✓`|`✓`|-|
|0xD1A8|MovieShutterSpeed|6.5.12.10|-|`✓`|`✓`|
|0xD1A9|MovieFnumber|6.5.12.9|-|`✓`|`✓`|
|0xD1AA|MovieExposureIndex|6.5.3.8|`✓`|`✓`|`✓`|



Do Not Copy 

155/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

|0xD1AB|MovieExposureBiasCompensation|6.5.12.11|-|`✓`|`✓`|
|---|---|---|---|---|---|
|0xD1AC|LiveViewImageSize|6.5.12.4|`✓`|`✓`|-|
|0xD1AD|SilentPhotography|6.5.2.68|`✓`|`✓`|-|
|0xD1AF|MovieExposureMeteringMode|6.5.3.54|`✓`|`✓`|-|
|0xD1B0|ExposureDisplayStatus|6.5.7.16||||
|0xD1B1|ExposureIndicateStatus|6.5.7.17||||
|0xD1B2|InfoDisplayErrorStatus|6.5.7.24||||
|0xD1B3|ExposureIndicateLightup|6.5.7.18||||
|0xD1B4|ContinuousShootingCount|6.5.7.6||||
|0xD1B7|MovieRecFrameCount|6.5.7.7||||
|0xD1B8|CameraLiveViewStatus|6.5.12.1||||
|0xD1B9|DetectionPeaking|6.5.4.19|`✓`|`✓`|`✓`|
|0xD1BA|MonitorOffStatus|6.5.7.19||||
|0xD1BB|LiveViewImageStatus|6.5.12.3||||
|0xD1BC|LiveViewImageCompression|6.5.12.5|`✓`|`✓`|-|
|0xD1BD|LiveViewZoomArea|6.5.12.6|`✓`|`✓`|`✓`|
|0xD1C5|AutoFlashIsoSensitivityControl|6.5.4.23|`✓`|`✓`|-|
|0xD1DE|ExternalRecordingControl|6.5.5.11|`✓`|`✓`|-|
|0xD1DF|HighlightBrightness|6.5.4.32|`✓`|`✓`|`✓`|
|0xD1E2|SBWirelessMode|6.5.9.7|`✓`|-|-|
|0xD1E3|SBWirelessMultipleFlashMode|6.5.9.8|`✓`|-|-|
|0xD1E4|SBUsableGroup|6.5.9.9||||
|0xD1E5|WirelessCLSEntryMode|6.5.9.10|`✓`|`✓`|-|
|0xD1E6|SBPINCode|6.5.9.11|`✓`|`✓`|-|
|0xD1E7|RadioMultipleFlashChannel|6.5.9.12||||
|0xD1E8|OpticalMultipleFlashChannel|6.5.9.13|`✓`|-|-|
|0xD1E9|FlashRangeDisplay|6.5.9.14||||
|0xD1EA|AllTestFiringDisable|6.5.9.15||||
|0xD1EC|SBSettingMemberLock|6.5.9.16|`✓`|-|-|
|0xD1ED|SBIntegrationFlashReady|6.5.9.17||||
|0xD1F1|ExposureRemaining|6.5.7.5||||
|0xD1F2|ActiveSlot|6.5.7.4||||
|0xD1F4|ISOAutoShutterTimeCorrectionValue|6.5.2.13|`✓`|`✓`|-|
|0xD1F8|MovieFocusMeteringMode|6.5.3.54|`✓`|`✓`|`✓`|
|0xD1F9|MovieVibrationReduction|6.5.3.55|`✓`|`✓`|`✓`|
|0xD1FA|MovieFocusMode|6.5.3.53|`✓`|`✓`|`✓`|
|0xD1FB|RecordTimeCodes|6.5.3.62|`✓`|`✓`|-|
|0xD1FC|CountUpMethod|6.5.3.63|`✓`|`✓`|-|
|0xD1FD|TimeCodeOrigin|6.5.3.64|`✓`|`✓`|-|
|0xD1FE|DropFrame|6.5.3.65|`✓`|`✓`|-|
|0xD1FF|StillCaptureModeSaveFrame|6.5.7.15|`✓`|`✓`|-|
|0xD200|ActivePicCtrlItem|6.5.13.1|`✓`|`✓`|-|
|0xD20D|ElectronicFrontCurtainShutter|6.5.4.15|`✓`|`✓`|-|
|0xD20F|MovieCaptureAreaCrop|6.5.3.2|`✓`|`✓`|-|
|0xD211|MovieWbAutoType|6.5.3.10|`✓`|`✓`|`✓`|
|0xD212|MovieWbTuneAuto|6.5.3.11|`✓`|`✓`|`✓`|
|0xD213|MovieWbTuneIncandescent|6.5.3.16|`✓`|`✓`|`✓`|
|0xD214|MovieWbFluorescentType|6.5.3.17|`✓`|`✓`|`✓`|
|0xD215|MovieWbTuneFluorescent|6.5.3.18|`✓`|`✓`|`✓`|
|0xD216|MovieWbTuneSunny|6.5.3.13|`✓`|`✓`|`✓`|
|0xD218|MovieWbTuneCloudy|6.5.3.14|`✓`|`✓`|`✓`|
|0xD219|MovieWbTuneShade|6.5.3.15|`✓`|`✓`|`✓`|
|0xD21A|MovieWbColorTemp|6.5.3.19|`✓`|`✓`|`✓`|
|0xD21B|MovieWbTuneColorTemp|6.5.3.20|`✓`|`✓`|`✓`|
|0xD21C|MovieWbPresetDataNo|6.5.3.21|`✓`|`✓`|`✓`|
|0xD21D|MovieWbPresetDataComment1|6.5.3.22|`✓`|`✓`|-|
|0xD21E|MovieWbPresetDataComment2|6.5.3.23|`✓`|`✓`|-|
|0xD21F|MovieWbPresetDataComment3|6.5.3.24|`✓`|`✓`|-|
|0xD220|MovieWbPresetDataComment4|6.5.3.25|`✓`|`✓`|-|



Do Not Copy 

156/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

|0xD221|MovieWbPresetDataComment5|6.5.3.26|`✓`|`✓`|-|
|---|---|---|---|---|---|
|0xD222|MovieWbPresetDataComment6|6.5.3.27|`✓`|`✓`|-|
|0xD223|MovieWbPresetDataValue1|6.5.3.28||||
|0xD224|MovieWbPresetDataValue2|6.5.3.29||||
|0xD225|MovieWbPresetDataValue3|6.5.3.30||||
|0xD226|MovieWbPresetDataValue4|6.5.3.31||||
|0xD227|MovieWbPresetDataValue5|6.5.3.32||||
|0xD228|MovieWbPresetDataValue6|6.5.3.33||||
|0xD229|MovieWbTunePreset1|6.5.3.34|`✓`|`✓`|`✓`|
|0xD22A|MovieWbTunePreset2|6.5.3.35|`✓`|`✓`|`✓`|
|0xD22B|MovieWbTunePreset3|6.5.3.36|`✓`|`✓`|`✓`|
|0xD22C|MovieWbTunePreset4|6.5.3.37|`✓`|`✓`|`✓`|
|0xD22D|MovieWbTunePreset5|6.5.3.38|`✓`|`✓`|`✓`|
|0xD22E|MovieWbTunePreset6|6.5.3.39|`✓`|`✓`|`✓`|
|0xD22F|MovieWbPresetProtect1|6.5.3.40|`✓`|`✓`|-|
|0xD230|MovieWbPresetProtect2|6.5.3.41|`✓`|`✓`|-|
|0xD231|MovieWbPresetProtect3|6.5.3.42|`✓`|`✓`|-|
|0xD232|MovieWbPresetProtect4|6.5.3.43|`✓`|`✓`|-|
|0xD233|MovieWbPresetProtect5|6.5.3.44|`✓`|`✓`|-|
|0xD234|MovieWbPresetProtect6|6.5.3.45|`✓`|`✓`|-|
|0xD236|MovieNoiseReductionHiIso|6.5.3.47|`✓`|`✓`|-|
|0xD237|MovieActivePicCtrlItem|6.5.13.2|`✓`|`✓`|-|
|0xD239|ExposureBaseCompHighlight|6.5.4.11|`✓`|`✓`|-|
|0xD23A|MovieWhiteBalance|6.5.3.9|`✓`|`✓`|`✓`|
|0xD23B|MovieActive-D-Lighting|6.5.3.46|`✓`|`✓`|-|
|0xD23C|MovieWbTuneNatural|6.5.3.12|`✓`|`✓`|`✓`|
|0xD23D|MovieAttenuator|6.5.3.59|`✓`|`✓`|`✓`|
|0xD23E|MovieVignetteControl|6.5.3.48|`✓`|`✓`|-|
|0xD23F|MovieDiffractionCompensation|6.5.3.49|`✓`|`✓`|-|
|0xD303|UseDeviceStageFlag|6.5.14.3||||
|0xD314|ElectronicVR|6.5.3.56|`✓`|`✓`|-|
|0xD406|SessionInitiatorVersionInfo|6.5.14.1|`✓`|`✓`|-|
|0xD407|PerceivedDeviceType|6.5.14.2||||



Do Not Copy 

157/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1 Standard** 

## **6.5.1.1 BatteryLevel** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5001|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|DefaultValue|100 [100 %]|
|Property Value|From 1 [1 %] to 100 [100 %]|



## ○ **Property Outline** 

Indicates “Remaining battery level” of the camera. 

## ○ **Property Details** 

When the battery level is reduced, the PropertyValues sent by the camera are: 1%, 20%, 40%, 60%, 80%, and 100% only. 

The relationship between the PropertyValue and the remaining battery level display is shown below. 

|PropertyValue|Remaining batteryleveldisplay|
|---|---|
|100|5 / 5|
|80|4 / 5|
|60|3 / 5|
|40|2 / 5|
|20|1/ 5|
|1|1 / 5 (blinking)|



When the remaining battery level is 1% and the shutter release is disabled, the following settings are made. 

|No.|Description|
|---|---|
|1|The WarningStatus property (subsection 6.5.7.23) is set to“Battery exhausted”.|
|2|The LiveViewProhibitionCondition property (subsection 6.5.12.7) is set to“Battery exhausted”.|



Do Not Copy 

158/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.2 ImageSize** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5003|
|DataType|String|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|Size L|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Image size” that is set in the camera. 

For the change of RAW image size, refer to the RawImageSize property (subsection 6.5.2.4). 

## ○ **Property Details** 

This property indicates "Image Size-JPEG" in the photo shooting menu during live view photography. 

During the movie live view, it indicates the image size acquired by saving the frame. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|CaptureAreaCrop||PropertyValue|PropertyValue||
|---|---|---|---|---|
||FX|DX|1:1|16:9|
|Size L|6048x4024|3936x2624|4016x4016|6048x3400|
|SizeM|4528x3016|2944x1968|3008x3008|4528x2544|
|Size S|3024x2016|1968x1312|2000x2000|3024x1696|



The image size of photos taken in movie live view is as shown below. 

|MovieRecordScreenSize|PropertyValue|PropertyValue|
|---|---|---|
||4K|Full HD|
|Size|3840x2160|1920x1080|



Do Not Copy 

159/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.3 CompressionSetting** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5004|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|2 [JPEG (NORMAL)]|
|Property Value|Refer to Property Value in this subsection.|



- **Property Outline** 

Indicates “Image quality mode” that is set in the camera. 

## ○ **Property Details** 

This property indicates the control value in the camera, not a setting value in the menu.  This is a value including RAW when the Plus RAW function is valid. 

When StorageInfo DataSet (subsection 9.2) is changed according to the change of this property, the StorageInfoChanged event (subsection 6.4.1.11) is issued. 

JPEG (FINE `★` ) is set during movie live view. 

## ○ **Property Value** 

## The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|JPEG (BASIC)|
|1|JPEG(BASIC`★`)|
|2|JPEG (NORMAL)|
|3|JPEG(NORMAL`★`)|
|4|JPEG (FINE)|
|5|JPEG(FINE`★`)|
|7|RAW|
|8|RAW+JPEG (BASIC)|
|9|RAW+JPEG(BASIC`★`)|
|10|RAW+JPEG (NORMAL)|
|11|RAW+JPEG(NORMAL`★`)|
|12|RAW+JPEG (FINE)|
|13|RAW+JPEG(FINE`★`)|



Do Not Copy 

160/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.4 WhiteBalance** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5005|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x0002 [Auto]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “White Balance” that is set in the camera. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0002|Auto|
|0x0004|Sunny|
|0x0005|Fluorescent|
|0x0006|Incandescent|
|0x0007|Flash|
|0x8010|Cloudy|
|0x8011|Shade|
|0x8012|Choose color temp.|
|0x8013|Presetmanual|
|0x8016|Natural light auto|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||During movie recording, the MovieWhiteBalance (subsection 6.5.3.9) is<br>set to anything other than [Same as photo settings].|



Do Not Copy 

161/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.5 Fnumber** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5007|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|(Minimum value in the setting range)|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Aperture value” with the CPU internal lens mounted. 

## ○ **Property Details** 

When the LensSort property (subsection 6.5.10.1) is [Not mounted], the enumeration cannot be created.  Therefore the number of enumeration values shall be 1 and the enumeration value, the DefaultValue, and the PropertyValue shall be the same value. 

For models that support the exposure meter interlocking lever, it changes depending on the F0ManualSetting property (subsection 6.5.5.3) and the state of the exposure meter interlocking lever.  The value shall be 1 EV except the maximum aperture value. 

It is set to 0 if the model does not support the exposure meter interlocking lever or if the aperture value cannot be acquired. 

If an aperture value error occurs, the number of enumeration values shall be 1 and the enumeration value, the DefaultValue, and the PropertyValue shall be 0xFFFF. 

## ○ **Property Value** 

The PropertyValue should be a hundred times the aperture value. 

The PropertyValue changes depending on the value of the ExposureEVStep property (subsection 6.5.4.6). 

The setting range of PropertyValue changes depending on the lens and the magnification setting. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is anything<br>other than [A] or [M].|
||TheLensSort property (subsection6.5.10.1)is [Notmounted].|
||The WarningStatus property (subsection 6.5.7.23) is [Sequence error].|
||The RetractableLensWarning property (subsection 6.5.10.9) is<br>[(Retractablelenswarning) On].|
||The AVLockSetting property (subsection 6.5.4.27) is set to [On].|
||The aperturevalue error.|



Do Not Copy 

162/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.6 FocalLength** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5008|
|DataType|UINT32|
|Description form|Range|
|Get / Set|Get|
|Default Value|(Minimum value in the setting range)|
|Property Value|The value of a hundred times the focal length|



## ○ **Property Outline** 

Indicates “Focal length” with the CPU internal lens mounted. 

## ○ **Property Details** 

The setting range of PropertyValue changes depending on the lens and the magnification setting. When the LensSort property (subsection 6.5.10.1) is [Not mounted], the PropertyValue is not fixed. 

Do Not Copy 

163/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.7 FocusMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x500A|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0x8010 [Single AF]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Focus mode” that is set in the camera. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|Lv Photo|Movie Lv|
|---|---|---|---|
|0x0001|Manual focus(MF)|`✓`|`✓`|
|0x8010|Single AF(AF-S)|`✓`|`✓`|
|0x8011|Continuous AF(AF-C)|`✓`|`✓`|
|0x8013|Full time AF(AF-F)|`-`|`✓`|



Do Not Copy 

164/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.8 ExposureMeteringMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x500B|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x0003 [Matrix metering]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Metering mode” that is set in the camera. 

Use the MovieExposureMeteringMode property (subsection 6.5.3.52) for the exposure metering mode during movie live view. 

## ○ **Property Details** 

In the following cases, this property operates with center-weighted metering. 

- The LensSort property (subsection 6.5.10.1) is set to [Not mounted] and highlight-weighted metering is selected. 

- When the lens information is not registered in “Non-CPU lens data” menu, the LensSort property (subsection 6.5.10.1) is set to [Not mounted] and matrix metering is selected. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0x0002|Center-weighted metering|
|0x0003|Matrix metering|
|0x0004|Spot metering|
|0x8010|Highlight-weighted metering|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The AELockStatus property (subsection 6.5.7.8) is [Locked].|



Do Not Copy 

165/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.9 FlashMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x500C|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x8010 [Normal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Flash mode” that is set in the camera. 

## ○ **Property Details** 

If Rear curtain is set when the ExposureProgramMode property (subsection 6.5.1.11) is set to P/S/A/M and the NewExternalSpeedLightMode property (subsection 6.5.9.4) is set to Multi-flash, normal flash is set. 

The camera display status depends on the value of the ExposureProgramMode property (subsection 6.5.1.11).  In addition, it also differs according to the external flash condition. 

When the camera is in the Access_Denied condition of this property or while movie live view is being performed, this property is set to [Flash off]. 

The camera display status with the external flash firing is shown below. 

|Shooting mode<br>or selected<br>scene|Normal flash|Normal flash +<br>slow shutter|Rear curtain<br>flash|Red-eye<br>reduction<br>flash|Red-eye reduction<br>flash + slow<br>shutter|Flash off|
|---|---|---|---|---|---|---|
|P / A|Normal flash|Normal flash +<br>slow shutter|Rear curtain<br>flash|Red-eye<br>reduction<br>flash|Red-eye reduction<br>flash + slow<br>shutter|Flash off|
|S / M|Normal flash|-|Rear curtain<br>flash|Red-eye<br>reduction<br>flash|-|Flash off|
|AUTO|Normal flash|-|-|Red-eye<br>reduction<br>flash|-|Flash off|
|U1/U2/U3|Depends on the ExposureProgramMode property set to user mode.||||||



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0002|Flash off|
|0x0004|Red-eye reduction flash|
|0x8010|Normal flash|
|0x8011|Normal flash +slowshutter|
|0x8012|Rear curtain flash|
|0x8013|Red-eyereduction +slowshutter|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The HDRMode property (subsection 6.5.2.64) is set to [On].|
||The SilentPhotography property (subsection 6.5.2.68) is set to [On].|
||During SB setting warning.|
||Duringimage dust offdata acquiringmode|



Do Not Copy 

166/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.10 ExposureTime** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x500D|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|(Minimum value in the setting range)|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Shutter speed” that is set in the camera. 

For the shutter speed during movie live view, the MovieShutterSpeed property (subsection 6.5.12.10) should be used. 

## ○ **Property Details** 

When the ExposureProgramMode property (subsection 6.5.1.11) is M, the following values are added to the enumerated value.  In the case of S, a value corresponding to the current value of bulb shooting/time shooting is added to the enumerated value. 

|PropertyValue|Use|Condition in which the value can be set|
|---|---|---|
|0xFFFFFFFF|Bulb shooting|ExposureProgramMode is M|
|0xFFFFFFFD|Time shooting|ExposureProgramMode is M|



The flash shooting synchronization speed is treated in the same manner as the ordinary shutter speed. 

When the flash shooting synchronization speed is set to 1/200, the PropertyValue shows 1/200. The flash shooting synchronization speed cannot be set. 

(This is because the value of PropertyValue is set as the ordinary shutter speed.) 

The enumerated values of shutter speed change depending on the value of the following properties. 

|Property|Reference|
|---|---|
|ExposureEVStep|6.5.4.6|
|ElectronicFrontCurtainShutter|6.5.4.15|
|ExtendedShutterSpeedsManual|6.5.4.16|
|ExternalSpeedLightExist|6.5.9.1|
|NewExternalSpeedLightMode|6.5.9.4|



When the ElectronicFrontCurtainShutter property (subsection 6.5.4.15) is set to [Electronic front curtain shutter], the minimum value is limited to 1/2000. 

When the ExtendedShutterSpeedsManual property is [ON] and the ExposureProgramMode property is [M], values over 30 seconds are added. 

Do Not Copy 

167/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

When the ExternalSpeedLightExist property (subsection 6.5.9.1) is set to [Mounted], the minimum value and the maximum value of the enumerated values depend on the conditions below. 

## Minimum value: 

The minimum value is limited to the slower value between Flash shooting synchronization speed (FlashSyncSpeed property, subsection 6.5.4.20) and the external flash speed limit.  The minimum value is not limited when the auto FP is supported by the flash mode of the external flash and the flash shooting synchronization speed is set to the auto FP. 

Maximum value: 

When both flash mode (FlashMode property, subsection 6.5.1.9) and shooting mode (ExposureProgramMode property, subsection 6.5.1.11) have the values shown below, it is limited to the value set by shutter speed limit with flash (FlashSlowSpeedLimit property, subsection 6.5.4.21). 

|Flash mode|Shooting mode|
|---|---|
|Red-eye reduction flash<br>Normal flash|P<br>A|



Because the unit of the PropertyValue is 1/10000, a rounding occurs in some range.  Use the ShutterSpeed property (subsection 6.5.7.11) to get the precise shutter speed. 

In this case, refer to the table below. 

EV in parentheses shows the exposure setting step range (ExposureEVStep property). 

|PropertyValue|Shutter speed|Shutter speed|
|---|---|---|
||Get|Set|
|1|1/8000 (1/3 EV, 1/2 EV)<br>1/6400 (1/3 EV)<br>1/6000 (1/2 EV)|1/8000|
|2|1/5000 (1/3 EV)<br>1/4000 (1/3 EV, 1/2 EV)|1/4000|
|3|1/3200 (1/3 EV)<br>1/3000 (1/2 EV)|1/3200 (1/3 EV)<br>1/3000 (1/2 EV)|
|6|1/1600 (1/3 EV)<br>1/1500 (1/2 EV)|1/1600 (1/3 EV)<br>1/1500 (1/2 EV)|



If there is a change in the enumerated values, the enumerated values and the DefaultValue are updated. 

## ○ **Property Value** 

The valid PropertyValues are shown below.  (Excluding bulb shooting and time shooting) 

Shutter speed x 10000 [unit: 1/10000 sec.] 

(Example) Shutter speed 1/250 sec.: PropertyValue = 40 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan[S] or[M].|
||The WarningStatus property (subsection 6.5.7.23) is [Sequence error]<br>or [Minimum aperture warning].|
||The TVLockSetting property (subsection 6.5.4.26) is set to [On].|
||The RetractableLensWarning property (subsection 6.5.10.9) is<br>[(Retractable lens warning) On].|
||Bulb shooting or time shooting is set when the ExposureProgramMode<br>property (subsection 6.5.1.11) is [S].|
||Bulb shooting or time shooting is set when the HDRMode property<br>(subsection 6.5.2.64) is set to [On].|



Do Not Copy 

168/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.11 ExposureProgramMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x500E|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x0002 [Program auto]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Shooting mode” that is set in the camera. 

## ○ **Property Details** 

When [U1], [U2] or [U3] is set in the shooting mode, the shooting mode set by the UserMode property (subsection 6.5.7.1) is used. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|Used setting|
|---|---|---|
|0x0001|[M] Manual|-|
|0x0002|[P]Program auto|-|
|0x0003|[A]Aperturepriorityauto|-|
|0x0004|[S]Shutterpriorityauto|-|
|0x8010|[Auto mode]AUTO|-|
|0x8050|[User mode]U1|UserMode (subsection 6.5.7.1)|
|0x8051|[User mode]U2||
|0x8052|[User mode]U3||



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|DuringPC camera mode.|
||Any value other than PSAM was set in the spot WB acquisition standby<br>state.|



Do Not Copy 

169/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.12 ExposureIndex** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x500F|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|100 [ISO100]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “ISO sensitivity” that is set in the camera. 

Refer to the MovieExposureIndex property (subsection 6.5.3.8) for the ISO sensitivity on the movie live view. 

## ○ **Property Details** 

The maximum ISO sensitivity of this camera is Hi-2.0 and the maximum value of this property is ISO51200.  When the value from Hi-0.3 to Hi-2.0 is set on the camera, this property value is set to ISO51200.  Use the ExposureIndexEx property (subsection 6.5.2.7) to handle the value from Hi-0.3 to Hi-5.0. 

When handling the value from Lo-1.0 to ISO51200, either of ExposureIndexEx property and this property may be used. 

The maximum ISO sensitivity value is limited in the following conditions.  Check the descriptor of this property to confirm available range. 

|No|Condition|
|---|---|
|1|The SilentPhotography property (subsection6.5.2.68)is set to [On].|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description||IsoStep||
|---|---|---|---|---|
|||1/3 step|1/2 step|1 step|
|50|Lo 1.0|`✓`|`✓`|`✓`|
|64|Lo 0.7|`✓`|-|-|
|72|Lo 0.5|-|`✓`|-|
|80|Lo 0.3|`✓`|-|-|
|100|100|`✓`|`✓`|`✓`|
|125|125|`✓`|-|-|
|140|140|-|`✓`|-|
|160|160|`✓`|-|-|
|200|200|`✓`|`✓`|`✓`|
|250|250|`✓`|-|-|
|280|280|-|`✓`|-|
|320|320|`✓`|-|-|
|400|400|`✓`|`✓`|`✓`|
|500|500|`✓`|-|-|
|560|560|-|`✓`|-|
|640|640|`✓`|-|-|
|800|800|`✓`|`✓`|`✓`|
|1000|1000|`✓`|-|-|
|1100|1100|-|`✓`|-|
|1250|1250|`✓`|-|-|
|1600|1600|`✓`|`✓`|`✓`|
|2000|2000|`✓`|-|-|
|2200|2200|-|`✓`|-|
|2500|2500|`✓`|-|-|
|3200|3200|`✓`|`✓`|`✓`|



Do Not Copy 

170/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

|||||**Nikon**|
|---|---|---|---|---|
|4000|4000|`✓`|-|-|
|4500|4500|-|`✓`|-|
|5000|5000|`✓`|-|-|
|6400|6400|`✓`|`✓`|`✓`|
|8000|8000|`✓`|-|-|
|9000|9000|-|`✓`|-|
|10000|10000|`✓`|-|-|
|12800|12800|`✓`|`✓`|`✓`|
|16000|16000|`✓`|-|-|
|18000|18000|-|`✓`|-|
|20000|20000|`✓`|-|-|
|25600|25600|`✓`|`✓`|`✓`|
|32000|32000|`✓`|-|-|
|36000|36000|-|`✓`|-|
|40000|40000|`✓`|-|-|
|51200|51200|`✓`|`✓`|`✓`|



Do Not Copy 

171/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.13 ExposureBiasCompensation** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5010|
|DataType|INT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [0.0 EV]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the compensation value of “Exposure compensation” that is set in the camera. For the exposure compensation during movie live view, the MovieExposureBiasCompensation property (subsection 6.5.12.11) should be used. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

The value of PropertyValue changes depending on the value of the ExposureEVStep property (subsection 6.5.4.6). 

||||ExposureEVStep||
|---|---|---|---|---|
|Property Value|Description|1/3 step|1/2 step|1 step|
|+5000|+5.0 EV|`✓`|`✓`|`✓`|
|+4666|+4.7 EV|`✓`|-|-|
|+4500|+4.5 EV|-|`✓`|-|
|+4333|+4.3 EV|`✓`|-|-|
|+4000|+4.0 EV|`✓`|`✓`|`✓`|
|+3666|+3.7 EV|`✓`|-|-|
|+3500|+3.5 EV|-|`✓`|-|
|+3333|+3.3 EV|`✓`|-|-|
|+3000|+3.0 EV|`✓`|`✓`|`✓`|
|+2666|+2.7 EV|`✓`|-|-|
|+2500|+2.5 EV|-|`✓`|-|
|+2333|+2.3 EV|`✓`|-|-|
|+2000|+2.0 EV|`✓`|`✓`|`✓`|
|+1666|+1.7 EV|`✓`|-|-|
|+1500|+1.5 EV|-|`✓`|-|
|+1333|+1.3 EV|`✓`|-|-|
|+1000|+1.0 EV|`✓`|`✓`|`✓`|
|+666|+0.7 EV|`✓`|-|-|
|+500|+0.5 EV|-|`✓`|-|
|+333|+0.3 EV|`✓`|-|-|
|0|0.0 EV|`✓`|`✓`|`✓`|
|-333|-0.3 EV|`✓`|-|-|
|-500|-0.5 EV|-|`✓`|-|
|-666|-0.7 EV|`✓`|-|-|
|-1000|-1.0 EV|`✓`|`✓`|`✓`|
|-1333|-1.3 EV|`✓`|-|-|
|-1500|-1.5 EV|-|`✓`|-|
|-1666|-1.7 EV|`✓`|-|-|
|-2000|-2.0 EV|`✓`|`✓`|`✓`|
|-2333|-2.3 EV|`✓`|-|-|
|-2500|-2.5 EV|-|`✓`|-|
|-2666|-2.7 EV|`✓`|-|-|
|-3000|-3.0 EV|`✓`|`✓`|`✓`|
|-3333|-3.3 EV|`✓`|-|-|
|-3500|-3.5 EV|-|`✓`|-|



Do Not Copy 

172/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

|-3666|-3.7 EV|`✓`|-|-|
|---|---|---|---|---|
|-4000|-4.0 EV|`✓`|`✓`|`✓`|
|-4333|-4.3 EV|`✓`|-|-|
|-4500|-4.5 EV|-|`✓`|-|
|-4666|-4.7 EV|`✓`|-|-|
|-5000|-5.0 EV|`✓`|`✓`|`✓`|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>[Automode].|



Do Not Copy 

173/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.14 DateTime** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5011|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|20200101T000000 [00:00:00, Jan. 1, 2020]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates “Date and time” that is set in the camera. 

## ○ **Property Details** 

The format of PropertyValue is a Unicode string of “YYYYMMDDThhmmss” where YYYY is the year, MM is the month, DD is the day of the month, T is a constant character, hh is the hours, mm is the minutes, and ss is the seconds past the minute, in accordance with the ISO8601 standards. 

The PropertyValue is the date and time obtained by “UTC + Time zone difference + Daylight saving time”. 

The setting range of PropertyValue is from 20000101T000000 to 20991231T235959. 

The format of PropertyValue is shown below. 

|Field|Size (Byte)|Data|Description|
|---|---|---|---|
|NumChar|1|0x10|The number of characters in the string.<br>It is sixteen (including the null character).|
|StringChars|32||Unicode string<br>“YYYYMMDDThhmmss”|



The DevicePropChanged event (subsection 6.4.1.6) is not issued even if this PropertyValue has changed. 

Do Not Copy 

174/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.15 StillCaptureMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5013|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x0001 [Single-frame shooting]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Release mode” that is set in the camera. 

Use ReleaseCaptureModeSaveFrame property (subsection 6.5.7.15) for the release mode (frame save) in the movie live view. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0001|Single-frame shooting|
|0x0002|Continuoushigh-speed shooting|
|0x8010|Continuous low-speed shooting|
|0x8011|Self-timer|
|0x8019|Continuous high-speed shooting (Extension)|



Do Not Copy 

175/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.16 BurstNumber** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x5018|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|1 [One frame]|
|Property Value|From 1 [One frame] to 65535 [65535 frames]|



## ○ **Property Outline** 

Indicates “The number of continuous shooting frames” captured by the command. 

## ○ **Property Details** 

For shooting by the command processing, the continuous shooting is performed until the number of frames set by this property is reached. 

Refer to Continuous Shooting (subsection 11.7.1) about the maximum number of continuous shooting. 

Do Not Copy 

176/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.1.17 Artist** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0x501E|
|DataType|String|
|Description form|None|
|Get / Set|Get|
|Default Value|NULL (0x00) 0 character|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates “Artist” that is set in the camera. 

## ○ **Property Details** 

For setting “Artist”, the ArtistV property (subsection 6.5.5.8) should be used. 

The PropertyValue is an optional string of 36 characters or shorter (not including the null character). 

If the artist is not set in the camera, the value is zero length string (not including the null character). 

## **6.5.1.18 Copyright** 

- **Property Specifications** 

|Property Code|0x501F|
|---|---|
|DataType|String|
|Description form|None|
|Get / Set|Get|
|DefaultValue|NULL(0x00) 0 character|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates “Copyright” that is set in the camera. 

## ○ **Property Details** 

For setting “Copyright”, the CopyrightV property (subsection 6.5.5.9) should be used. 

The PropertyValue is an optional string of 54 characters or shorter (not including the null character). 

If the copyright is not set in the camera, the value is zero length string (not including the null character). 

Do Not Copy 

177/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2 Vendor (Photo Shooting Menu)** 

## **6.5.2.1 PrimarySlot** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD156|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|DefaultValue|1[Slot1]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Primary slot” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|1|Slot 1|
|2|Slot2|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The HDRMode property (subsection 6.5.2.64) is set to [On].|



Do Not Copy 

178/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.2 Slot2ImageSaveMode** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD148|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Overflow]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Secondary slot function” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|Overflow|
|2|Backup|
|3|RAW primary-JPEG secondary|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The HDRMode property (subsection 6.5.2.64) is set to [On].|



Do Not Copy 

179/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.3 CaptureAreaCrop** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD030|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [FX]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Image area” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|FX|
|2|DX|
|4|1:1|
|5|16:9|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|A DX lensismounted onthe camera.|



Do Not Copy 

180/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.4 RawImageSize** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0B6|
|DataType|String|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|Size L|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Image size - RAW” set on the camera. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

PropertyValue changes depending on the value of the CaptureAreaCrop property (subsection 6.5.2.3). The size is the same as the ImageSize property (subsection 6.5.1.2). 

|Property Value|Description|
|---|---|
|Same as size L of ImageSize property|Size L|
|Same as sizeMof ImageSize property|SizeM|
|Same as size S of ImageSize property|Size S|



Do Not Copy 

181/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.5 RawCompressionType** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD016|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Lossless compressed]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “NEF (RAW) recording – Compression type” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Lossless compressed|
|1|Compressed|
|2|Uncompressed RAW|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The RawImageSize property (subsection 6.5.2.4) is set to anything<br>otherthan[SizeL].|



Do Not Copy 

182/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.6 RawCompressionBitMode** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD149|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|14 [14-bit]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “NEF (RAW) recording - NEF (RAW) bit depth” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|12|12-bit|
|14|14-bit|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The RawImageSize property (subsection 6.5.2.4) is set to anything<br>other than [Size L].|



Do Not Copy 

183/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.7 ExposureIndexEx** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0B4|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|100 [ISO100]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “ISO sensitivity” that is set in the camera. 

This property is 32bit-expanded version of ExposureIndex property (subsection 6.5.1.12) and is able to use Hi-0.3 and above. 

Refer to the MovieExposureIndex property (subsection 6.5.3.8) for the ISO sensitivity on the movie live view. 

## ○ **Property Details** 

Both ExposureIndex property (subsection 6.5.1.12) and this property can be used when setting from Lo-1.0 to ISO51200. This property should be used when setting Hi-0.3 and above. 

The maximum ISO sensitivity value is limited in the following conditions.  Check the descriptor of this property to confirm available range. 

|No|Condition|
|---|---|
|1|The SilentPhotography property (subsection 6.5.2.68) is set to [On].|



## ○ **Property Value** 

## The valid PropertyValues are shown below. 

|Property Value|Description|ExposureEVStep|ExposureEVStep|ExposureEVStep|
|---|---|---|---|---|
|||1/3 step|1/2 step|1 step|
|50|Lo 1.0|`✓`|`✓`|`✓`|
|64|Lo 0.7|`✓`|-|-|
|72|Lo 0.5|-|`✓`|-|
|80|Lo 0.3|`✓`|-|-|
|100|100|`✓`|`✓`|`✓`|
|125|125|`✓`|-|-|
|140|140|-|`✓`|-|
|160|160|`✓`|-|-|
|200|200|`✓`|`✓`|`✓`|
|250|250|`✓`|-|-|
|280|280|-|`✓`|-|
|320|320|`✓`|-|-|
|400|400|`✓`|`✓`|`✓`|
|500|500|`✓`|-|-|
|560|560|-|`✓`|-|
|640|640|`✓`|-|-|
|800|800|`✓`|`✓`|`✓`|
|1000|1000|`✓`|-|-|
|1100|1100|-|`✓`|-|
|1250|1250|`✓`|-|-|
|1600|1600|`✓`|`✓`|`✓`|
|2000|2000|`✓`|-|-|
|2200|2200|-|`✓`|-|
|2500|2500|`✓`|-|-|
|3200|3200|`✓`|`✓`|`✓`|
|4000|4000|`✓`|-|-|
|4500|4500|-|`✓`|-|



Do Not Copy 

184/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

|||||**Nikon C**|
|---|---|---|---|---|
|5000|5000|`✓`|-|-|
|6400|6400|`✓`|`✓`|`✓`|
|8000|8000|`✓`|-|-|
|9000|9000|-|`✓`|-|
|10000|10000|`✓`|-|-|
|12800|12800|`✓`|`✓`|`✓`|
|16000|16000|`✓`|-|-|
|18000|18000|-|`✓`|-|
|20000|20000|`✓`|-|-|
|25600|25600|`✓`|`✓`|`✓`|
|32000|32000|`✓`|-|-|
|36000|36000|-|`✓`|-|
|40000|40000|`✓`|-|-|
|51200|51200|`✓`|`✓`|`✓`|
|64000|Hi 0.3|`✓`|-|-|
|72000|Hi 0.5|-|`✓`|-|
|81200|Hi 0.7|`✓`|-|-|
|102400|Hi 1.0|`✓`|`✓`|`✓`|
|204800|Hi 2.0|`✓`|`✓`|`✓`|



Do Not Copy 

185/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.8 ISOAutoSetting** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD16A|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|1 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the auto value of “ISO sensitivity settings – ISO sensitivity” in the photo shooting menu. 

## ○ **Property Details** 

This represents the state of auto ISO sensitivity control when the ExposureProgramMode property (subsection 6.5.1.11) is set to the value other than PSAM. 

When the ExposureProgramMode property is PSAM, the PropertyValue is not fixed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|On|
|1|Off|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>PSAM.|



Do Not Copy 

186/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.9 ISOAutoControl** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD054|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|1 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “ISO sensitivity settings – Auto ISO sensitivity control” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

187/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.10 ISOAutoHighLimit** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD183|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|51200 [ISO51200]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “ISO sensitivity settings – Auto ISO sensitivity control – Maximum sensitivity” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Maximum sensitivity|Maximum sensitivity|ExposureEVStep|ExposureEVStep|ExposureEVStep|
|---|---|---|---|---|
|PropertyValue|Description|1/3 step|1/2step|1step|
|200|200|`✓`|`✓`|`✓`|
|250|250|`✓`|-|-|
|280|280|-|`✓`|-|
|320|320|`✓`|-|-|
|400|400|`✓`|`✓`|`✓`|
|500|500|`✓`|-|-|
|560|560|-|`✓`|-|
|640|640|`✓`|-|-|
|800|800|`✓`|`✓`|`✓`|
|1000|1000|`✓`|-|-|
|1100|1100|-|`✓`|-|
|1250|1250|`✓`|-|-|
|1600|1600|`✓`|`✓`|`✓`|
|2000|2000|`✓`|-|-|
|2200|2200|-|`✓`|-|
|2500|2500|`✓`|-|-|
|3200|3200|`✓`|`✓`|`✓`|
|4000|4000|`✓`|-|-|
|4500|4500|-|`✓`|-|
|5000|5000|`✓`|-|-|
|6400|6400|`✓`|`✓`|`✓`|
|8000|8000|`✓`|-|-|
|9000|9000|-|`✓`|-|
|10000|10000|`✓`|-|-|
|12800|12800|`✓`|`✓`|`✓`|
|16000|16000|`✓`|-|-|
|18000|18000|-|`✓`|-|
|20000|20000|`✓`|-|-|
|25600|25600|`✓`|`✓`|`✓`|
|32000|32000|`✓`|-|-|
|36000|36000|-|`✓`|-|
|40000|40000|`✓`|-|-|
|51200|51200|`✓`|`✓`|`✓`|
|64000|Hi 0.3|`✓`|-|-|
|72000|Hi 0.5|-|`✓`|-|
|81200|Hi 0.7|`✓`|-|-|
|102400|Hi 1.0|`✓`|`✓`|`✓`|
|204800|Hi 2.0|`✓`|`✓`|`✓`|



Do Not Copy 

188/484 

**Confidential** 

**Nikon Corporation** 

## **Confidential** 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ISOAutoControl property (subsection 6.5.2.9) is set to [Off].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

189/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.11 FlashISOAutoHighLimit** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD199|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0xFFFFFFFF [The setting in the case that the flash is not attached]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “ISO sensitivity settings – Auto ISO sensitivity control – Maximum sensitivity with flash” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|From 200 to 204800|Refer to the property value of ISOAutoHighLimit<br>(subsection 6.5.2.10).|
|0xFFFFFFFF|The settinginthe case that theflash isnot attached.|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheISOAutoControlproperty (subsection6.5.2.9)is set to [Off].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

190/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.12 ISOAutoShutterTime** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD164|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0xFFFFFFFF [Auto]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “ISO sensitivity settings – Auto ISO sensitivity control – Minimum shutter speed” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x00010FA0|1/4000 sec.|
|0x00010C80|1/3200 sec.|
|0x000109C4|1/2500 sec.|
|0x000107D0|1/2000 sec.|
|0x00010640|1/1600 sec.|
|0x000104E2|1/1250 sec.|
|0x000103E8|1/1000 sec.|
|0x00010320|1/800 sec.|
|0x00010280|1/640 sec.|
|0x000101F4|1/500 sec.|
|0x00010190|1/400 sec.|
|0x00010140|1/320 sec.|
|0x000100FA|1/250 sec.|
|0x000100C8|1/200 sec.|
|0x000100A0|1/160 sec.|
|0x0001007D|1/125 sec.|
|0x00010064|1/100 sec.|
|0x00010050|1/80 sec.|
|0x0001003C|1/60 sec.|
|0x00010032|1/50 sec.|
|0x00010028|1/40 sec.|
|0x0001001E|1/30 sec.|
|0x00010019|1/25 sec.|
|0x00010014|1/20 sec.|
|0x0001000F|1/15 sec.|
|0x0001000D|1/13 sec.|
|0x0001000A|1/10 sec.|
|0x00010008|1/8 sec.|
|0x00010006|1/6 sec.|
|0x00010005|1/5 sec.|
|0x00010004|1/4 sec.|
|0x00010003|1/3 sec.|
|0x000A0019|1/2.5 sec.|
|0x00010002|1/2 sec.|
|0x000A0010|1/1.6 sec.|
|0x000A000D|1/1.3 sec.|
|0x00010001|1 sec.|
|0x000D000A|1.3 sec.|
|0x0010000A|1.6 sec.|



Do Not Copy 

191/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

||**Nikon Co**|
|---|---|
|0x00020001|2 sec.|
|0x0019000A|2.5 sec.|
|0x00030001|3 sec.|
|0x00040001|4 sec.|
|0x00050001|5 sec.|
|0x00060001|6 sec.|
|0x00080001|8 sec.|
|0x000A0001|10 sec.|
|0x000D0001|13 sec.|
|0x000F0001|15 sec.|
|0x00140001|20 sec.|
|0x00190001|25 sec.|
|0x001E0001|30 sec.|
|0xFFFFFFFF|Auto|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ISOAutoControl property (subsection 6.5.2.9) is set to [Off].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

192/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.13 ISOAutoShutterTimeCorrectionValue** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1F4|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0|
|Property Value|From-2 to+2|



## ○ **Property Outline** 

Indicates the correction value when “ISO sensitivity settings – Auto ISO sensitivity control – Minimum shutter speed” in the photo shooting menu is [Auto]. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ISOAutoControl property (subsection 6.5.2.9) is set to [Off].|
||The ISOAutoShutterTime property (subsection 6.5.2.12) is not set to<br>[Auto].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

193/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.14 WbAutoType** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD141|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Keep overall atmosphere]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the type of “White balance - Auto” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Keep overall atmosphere|
|1|Keep warm lighting colors|
|2|Keep white|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



## **6.5.2.15 WbTuneAuto** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD017|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance - Auto” in the photo shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything otherthan[Same as photo settings] duringmovierecording.|



Do Not Copy 

194/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.16 WbTuneNatural** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD15E|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance – Natural light auto” in the photo shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



## **6.5.2.17 WbTuneSunny** 

## ○ **Property Specifications** 

|Property Code|0xD01A|
|---|---|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|PropertyValue|From0 to1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance – Direct sunlight” in the photo shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything otherthan[Same as photo settings] duringmovierecording.|



Do Not Copy 

195/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.18 WbTuneCloudy** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD01C|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance - Cloudy” in the photo shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything otherthan[Same as photo settings] duringmovierecording.|



## **6.5.2.19 WbTuneShade** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD01D|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance – Shade” in the photo shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



Do Not Copy 

196/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.20 WbTuneIncandescent** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD018|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance - Incandescent” in the photo shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything otherthan[Same as photo settings] duringmovierecording.|



Do Not Copy 

197/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.21 WbFluorescentType** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD14F|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|3 [White fluorescent lamp]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the light source of “White balance - Fluorescent” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Sodium lamp mixed light|
|1|Cool white fluorescent lamp|
|2|Warm white fluorescent lamp|
|3|Whitefluorescentlamp|
|4|Day white fluorescent lamp|
|5|Daylight fluorescent lamp|
|6|High color-temperature mercury lamp|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



## **6.5.2.22 WbTuneFluorescent** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD019|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|PropertyValue|From0 to1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance - Fluorescent” in the photo shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



Do Not Copy 

198/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.23 WbTuneFlash** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD01B|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance - Flash” in the photo shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



Do Not Copy 

199/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.24 WbColorTemp** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD01E|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|5000 [K]|
|Property Value|From 2500 K to 10000 K (increase or decrease in units of 10 K)|



## ○ **Property Outline** 

Indicates the color temperature (K) of “White balance – Choose color temp.” in the photo shooting menu. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



## **6.5.2.25 WbTuneColorTemp** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD150|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|24|
|Property Value|From 0 to 48|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance – Choose color temp.” in the photo shooting menu. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything otherthan[Same as photo settings] duringmovierecording.|



Do Not Copy 

200/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.26 WbPresetDataNo** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD01F|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|1 [d-1]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “White balance – Preset manual” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|d-1|
|2|d-2|
|3|d-3|
|4|d-4|
|5|d-5|
|6|d-6|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything otherthan[Same as photo settings] duringmovierecording.|



Do Not Copy 

201/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.27 WbPresetDataComment1** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD021|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-1” in the photo shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|
|Access_Denied|The WbPresetProtect1 property (subsection 6.5.2.45) is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



## **6.5.2.28 WbPresetDataComment2** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD022|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-2” in the photo shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|
|Access_Denied|The WbPresetProtect2 property (subsection 6.5.2.46) is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

202/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.29 WbPresetDataComment3** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD023|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-3” in the photo shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|
|Access_Denied|TheWbPresetProtect3 property (subsection6.5.2.47)is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



## **6.5.2.30 WbPresetDataComment4** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD024|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|PropertyValue|(Depends onthe usersetting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-4” in the photo shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|
|Access_Denied|TheWbPresetProtect4property (subsection6.5.2.48)is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

203/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.31 WbPresetDataComment5** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD038|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-5” in the photo shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|
|Access_Denied|TheWbPresetProtect5 property (subsection6.5.2.49)is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



## **6.5.2.32 WbPresetDataComment6** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD039|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|PropertyValue|(Depends onthe usersetting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-6” in the photo shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|
|Access_Denied|TheWbPresetProtect6 property (subsection6.5.2.50)is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

204/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.33 WbPresetDataValue1** 

- **Property Specifications** 

|Property Code|0xD026|
|---|---|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-1” in the photo shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

## **6.5.2.34 WbPresetDataValue2** 

- **Property Specifications** 

|Property Code|0xD027|
|---|---|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|PropertyValue|(Depends onthe usersetting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-2” in the photo shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

## **6.5.2.35 WbPresetDataValue3** 

## ○ **Property Specifications** 

|Property Code|0xD028|
|---|---|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|PropertyValue|(Depends onthe usersetting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-3” in the photo shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

Do Not Copy 

205/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.36 WbPresetDataValue4** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD029|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-4” in the photo shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

## **6.5.2.37 WbPresetDataValue5** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD03E|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-5” in the photo shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

## **6.5.2.38 WbPresetDataValue6** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD03F|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-6” in the photo shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

Do Not Copy 

206/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.39 WbTunePreset1** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD152|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-1” in the photo shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The WbPresetProtect1 property (subsection 6.5.2.45) is [On].|
||The WbPresetDataNo property (subsection 6.5.2.26) is set to anything<br>other than [d-1].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



## **6.5.2.40 WbTunePreset2** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD153|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|PropertyValue|From0 to1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-2” in the photo shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The WbPresetProtect2 property (subsection 6.5.2.46) is [On].|
||The WbPresetDataNo property (subsection 6.5.2.26) is set to anything<br>other than [d-2].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



Do Not Copy 

207/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.41 WbTunePreset3** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD154|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-3” in the photo shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The WbPresetProtect3 property (subsection 6.5.2.47) is [On].|
||The WbPresetDataNo property (subsection 6.5.2.26) is set to anything<br>other than [d-3].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



## **6.5.2.42 WbTunePreset4** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD155|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|PropertyValue|From0 to1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-4” in the photo shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The WbPresetProtect4 property (subsection 6.5.2.48) is [On].|
||The WbPresetDataNo property (subsection 6.5.2.26) is set to anything<br>other than [d-4].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



Do Not Copy 

208/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.43 WbTunePreset5** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD03A|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-5” in the photo shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The WbPresetProtect5 property (subsection 6.5.2.49) is [On].|
||The WbPresetDataNo property (subsection 6.5.2.26) is set to anything<br>other than [d-5].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



## **6.5.2.44 WbTunePreset6** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD03B|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|PropertyValue|From0 to1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-6” in the photo shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The WbPresetProtect6 property (subsection 6.5.2.50) is [On].|
||The WbPresetDataNo property (subsection 6.5.2.26) is set to anything<br>other than [d-6].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to<br>anything other than [Same as photo settings] during movie recording.|



Do Not Copy 

209/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.45 WbPresetProtect1** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD158|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-1” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



## **6.5.2.46 WbPresetProtect2** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD159|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-2” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

210/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.47 WbPresetProtect3** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD15A|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-3” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



## **6.5.2.48 WbPresetProtect4** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD15C|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-4” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

211/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.49 WbPresetProtect5** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD03C|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-5” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



## **6.5.2.50 WbPresetProtect6** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD03D|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-6” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

212/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.51 ColorSpace** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD032|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [sRGB]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Color space” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|sRGB|
|1|Adobe RGB|



Do Not Copy 

213/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.52 Active-D-Lighting** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD14E|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x0000 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Active D-Lighting” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Off|
|0x0002|Low|
|0x0003|Normal|
|0x0004|High|
|0x0005|Extra high|
|0xFFFF|Auto|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

214/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.53 NoiseReduction** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD06B|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Long exposure NR” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The SilentPhotography property (subsection6.5.2.68)is set to [On].|



Do Not Copy 

215/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.54 NoiseReductionHiIso** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD070|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x0003 [Normal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “High ISO NR” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Off|
|0x0002|Low|
|0x0003|Normal|
|0x0004|High|



Do Not Copy 

216/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.55 VignetteControl** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0F7|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x0003 [Normal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Vignette control” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Off|
|0x0002|Low|
|0x0003|Normal|
|0x0004|High|



Do Not Copy 

217/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.56 DiffractionCompensation** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0BA|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|1 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Diffraction compensation” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



Do Not Copy 

218/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.57 AutoDistortion** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0F8|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get, Get / Set|
|Default Value|1 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Auto distortion control” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The LensTypeML property (subsection 6.5.10.2) is set to [Lens whose<br>automatic distortion correction is alwayseffective].|



Do Not Copy 

219/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.58 FlickerReductionSetting** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0B7|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Flicker reduction shooting” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheExposureDelay property (subsection6.5.4.14)isnot set to [Off].|
||The HDRMode property (subsection 6.5.2.64) is set to [On].|
||The SilentPhotography property (subsection6.5.2.68)is set to [On].|



Do Not Copy 

220/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.59 InternalFlashCompensation** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD126|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get, Get / Set|
|Default Value|0|
|Property Value|From-18 to+6|



## ○ **Property Outline** 

Indicates “Flash compensation value” of the camera in units of 1/6 EV. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description||ExposureEVStep||
|---|---|---|---|---|
|||1/3 EV|1/2 EV|1 EV|
|-18|-3.0EV|`✓`|`✓`|`✓`|
|-16|-2.7EV|`✓`|-|-|
|-15|-2.5EV|-|`✓`|-|
|-14|-2.3EV|`✓`|-|-|
|-12|-2.0EV|`✓`|`✓`|`✓`|
|-10|-1.7EV|`✓`|-|-|
|-9|-1.5EV|-|`✓`|-|
|-8|-1.3EV|`✓`|-|-|
|-6|-1.0EV|`✓`|`✓`|`✓`|
|-4|-0.7EV|`✓`|-|-|
|-3|-0.5EV|-|`✓`|-|
|-2|-0.3EV|`✓`|-|-|
|0|0.0EV|`✓`|`✓`|`✓`|
|2|0.3EV|`✓`|-|-|
|3|0.5EV|-|`✓`|-|
|4|0.7EV|`✓`|-|-|
|6|1.0EV|`✓`|`✓`|`✓`|



The StepSize of this property changes depending on the value of the ExposureEVStep property (subsection 6.5.4.6). 

|ExposureCompEVStep|StepSize|
|---|---|
|0 (1/3EV)|2|
|1 (1/2 EV)|3|
|2(1 EV)|6|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The HDRMode property (subsection 6.5.2.64) is set to [On].|
||The SilentPhotography property (subsection6.5.2.68)is set to [On].|
||During SB setting warning.|
||Duringimage dust offdata acqusition mode.|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

221/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.60 StillFocusMode** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD061|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [AF-S]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Focus mode” in photo shooting. 

## ○ **Property Details** 

Even if this property is set to AF, this property is set to MF when the focus mode is set to MF due to the CPU lens not attached or the operation with the camera dial/switch. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|AF-S|
|1|AF-C|
|4|MF|



Do Not Copy 

222/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.61 StillFocusMeteringMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD05D|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x8020 [Auto-area AF (Person)]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “AF-area mode” in photo shooting. 

## ○ **Property Details** 

In the following cases, this property is set to the single-point AF mode. When the following state is canceled without changing the AF area mode, it returns to the AF area mode which was set immediately before. 

- In the case that the StillFocusMode property (subsection 6.5.2.60) is set to [MF]. 

- In the case that the AF area mode that cannot be selected is set when the StillFocusMode property (subsection 6.5.2.60) is changed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|The value of PropertyValue changes depending on the still image focus mode setting.<br>Property<br>Value<br>Description<br>Still image focus mode setting<br>MF<br>AF-S<br>AF-C<br>0x0002<br>Dynamic AF<br>-<br>-<br>`✓`<br>0x8010<br>Single-point AF<br>`✓`<br>`✓`<br>`✓`<br>0x8011<br>Auto-area AF<br>-<br>`✓`<br>`✓`<br>0x8017<br>Pinpoint AF<br>-<br>`✓`<br>-<br>0x8018<br>Wide-area AF(S)<br>-<br>`✓`<br>`✓`<br>0x8019<br>Wide-area AF(L)<br>-<br>`✓`<br>`✓`<br>0x801A<br>Wide-area AF(L - Person)<br>-<br>`✓`<br>`✓`<br>0x801B<br>Wide-area AF(L - Animal)<br>-<br>`✓`<br>`✓`<br>0x8020<br>Auto-area AF(Person)<br>-<br>`✓`<br>`✓`<br>0x8021<br>Auto-area AF(Animal)<br>-<br>`✓`<br>`✓`|The value of PropertyValue changes depending on the still image focus mode setting.<br>Property<br>Value<br>Description<br>Still image focus mode setting<br>MF<br>AF-S<br>AF-C<br>0x0002<br>Dynamic AF<br>-<br>-<br>`✓`<br>0x8010<br>Single-point AF<br>`✓`<br>`✓`<br>`✓`<br>0x8011<br>Auto-area AF<br>-<br>`✓`<br>`✓`<br>0x8017<br>Pinpoint AF<br>-<br>`✓`<br>-<br>0x8018<br>Wide-area AF(S)<br>-<br>`✓`<br>`✓`<br>0x8019<br>Wide-area AF(L)<br>-<br>`✓`<br>`✓`<br>0x801A<br>Wide-area AF(L - Person)<br>-<br>`✓`<br>`✓`<br>0x801B<br>Wide-area AF(L - Animal)<br>-<br>`✓`<br>`✓`<br>0x8020<br>Auto-area AF(Person)<br>-<br>`✓`<br>`✓`<br>0x8021<br>Auto-area AF(Animal)<br>-<br>`✓`<br>`✓`|The value of PropertyValue changes depending on the still image focus mode setting.<br>Property<br>Value<br>Description<br>Still image focus mode setting<br>MF<br>AF-S<br>AF-C<br>0x0002<br>Dynamic AF<br>-<br>-<br>`✓`<br>0x8010<br>Single-point AF<br>`✓`<br>`✓`<br>`✓`<br>0x8011<br>Auto-area AF<br>-<br>`✓`<br>`✓`<br>0x8017<br>Pinpoint AF<br>-<br>`✓`<br>-<br>0x8018<br>Wide-area AF(S)<br>-<br>`✓`<br>`✓`<br>0x8019<br>Wide-area AF(L)<br>-<br>`✓`<br>`✓`<br>0x801A<br>Wide-area AF(L - Person)<br>-<br>`✓`<br>`✓`<br>0x801B<br>Wide-area AF(L - Animal)<br>-<br>`✓`<br>`✓`<br>0x8020<br>Auto-area AF(Person)<br>-<br>`✓`<br>`✓`<br>0x8021<br>Auto-area AF(Animal)<br>-<br>`✓`<br>`✓`|The value of PropertyValue changes depending on the still image focus mode setting.<br>Property<br>Value<br>Description<br>Still image focus mode setting<br>MF<br>AF-S<br>AF-C<br>0x0002<br>Dynamic AF<br>-<br>-<br>`✓`<br>0x8010<br>Single-point AF<br>`✓`<br>`✓`<br>`✓`<br>0x8011<br>Auto-area AF<br>-<br>`✓`<br>`✓`<br>0x8017<br>Pinpoint AF<br>-<br>`✓`<br>-<br>0x8018<br>Wide-area AF(S)<br>-<br>`✓`<br>`✓`<br>0x8019<br>Wide-area AF(L)<br>-<br>`✓`<br>`✓`<br>0x801A<br>Wide-area AF(L - Person)<br>-<br>`✓`<br>`✓`<br>0x801B<br>Wide-area AF(L - Animal)<br>-<br>`✓`<br>`✓`<br>0x8020<br>Auto-area AF(Person)<br>-<br>`✓`<br>`✓`<br>0x8021<br>Auto-area AF(Animal)<br>-<br>`✓`<br>`✓`|The value of PropertyValue changes depending on the still image focus mode setting.<br>Property<br>Value<br>Description<br>Still image focus mode setting<br>MF<br>AF-S<br>AF-C<br>0x0002<br>Dynamic AF<br>-<br>-<br>`✓`<br>0x8010<br>Single-point AF<br>`✓`<br>`✓`<br>`✓`<br>0x8011<br>Auto-area AF<br>-<br>`✓`<br>`✓`<br>0x8017<br>Pinpoint AF<br>-<br>`✓`<br>-<br>0x8018<br>Wide-area AF(S)<br>-<br>`✓`<br>`✓`<br>0x8019<br>Wide-area AF(L)<br>-<br>`✓`<br>`✓`<br>0x801A<br>Wide-area AF(L - Person)<br>-<br>`✓`<br>`✓`<br>0x801B<br>Wide-area AF(L - Animal)<br>-<br>`✓`<br>`✓`<br>0x8020<br>Auto-area AF(Person)<br>-<br>`✓`<br>`✓`<br>0x8021<br>Auto-area AF(Animal)<br>-<br>`✓`<br>`✓`|The value of PropertyValue changes depending on the still image focus mode setting.<br>Property<br>Value<br>Description<br>Still image focus mode setting<br>MF<br>AF-S<br>AF-C<br>0x0002<br>Dynamic AF<br>-<br>-<br>`✓`<br>0x8010<br>Single-point AF<br>`✓`<br>`✓`<br>`✓`<br>0x8011<br>Auto-area AF<br>-<br>`✓`<br>`✓`<br>0x8017<br>Pinpoint AF<br>-<br>`✓`<br>-<br>0x8018<br>Wide-area AF(S)<br>-<br>`✓`<br>`✓`<br>0x8019<br>Wide-area AF(L)<br>-<br>`✓`<br>`✓`<br>0x801A<br>Wide-area AF(L - Person)<br>-<br>`✓`<br>`✓`<br>0x801B<br>Wide-area AF(L - Animal)<br>-<br>`✓`<br>`✓`<br>0x8020<br>Auto-area AF(Person)<br>-<br>`✓`<br>`✓`<br>0x8021<br>Auto-area AF(Animal)<br>-<br>`✓`<br>`✓`|
|---|---|---|---|---|---|
||Property|Dii|Still image focus mode setting|||
||Value|escrpton|MF|AF-S|AF-C|
||0x0002|Dynamic AF|-|-|`✓`|
||0x8010|Single-point AF|`✓`|`✓`|`✓`|
||0x8011|Auto-area AF|-|`✓`|`✓`|
||0x8017|Pinpoint AF|-|`✓`|-|
||0x8018|Wide-area AF(S)|-|`✓`|`✓`|
||0x8019|Wide-area AF(L)|-|`✓`|`✓`|
||0x801A|Wide-area AF(L - Person)|-|`✓`|`✓`|
||0x801B|Wide-area AF(L - Animal)|-|`✓`|`✓`|
||0x8020|Auto-area AF(Person)|-|`✓`|`✓`|
||0x8021|Auto-area AF(Animal)|-|`✓`|`✓`|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The photo focus mode is set to the manual focus.<br>NOTE) Except when the focus mode is set to MF due to the CPU lens<br>not attached orthe operation withthe camera dial/switch.|



Do Not Copy 

223/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.62 VibrationReduction** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD138|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|1 [Normal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Vibration reduction” in the photo setting menu. 

## ○ **Property Details** 

The supported Property Value differs depending on the type of attached lens. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

## When the lens anti-vibration mode is normal or sports: 

|Property Value|Description|
|---|---|
|0|Off|
|1|Normal|
|2|Sports|
|ns anti-vibration mode is|normal only:|
|Property Value|Description|
|0|Off|
|1|On|



When the lens anti-vibration mode is normal only: 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The mounted lens has VR switch.|
||The LensSort property (subsection 6.5.10.1) is set to [Not mounted]<br>and the FmmManualSetting property (subsection 6.5.5.2) is set to [Not<br>set].|



Do Not Copy 

224/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.63 BracketingType** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD078|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [AE & flash]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Auto bracketing - Auto bracketing set” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|AE & flash|
|1|AE only|
|2|Flash only|
|3|WBbracketing|
|4|ADL bracketing|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

225/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.64 HDRMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD130|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x000 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “HDR (high dynamic range) – HDR mode” in the photo shooting menu. 

## ○ **Property Details** 

When the StillCaptureMode property (subsection 6.5.1.15) is [Continuous low-speed shooting] or [Continuous high-speed shooting], HDR is applied to only the first image with the continuous shot operation. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Off|
|0x0001|On(single photo)|
|0x0101|On (series)|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The EnableBracketing property (subsection 6.5.8.1) is set to [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

226/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.65 HDREv** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD131|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0xFF [Auto]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “HDR (high dynamic range) – Exposure differential” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x06|1EV|
|0x0C|2EV|
|0x12|3EV|
|0xFF|Auto|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheEnableBracketing property (subsection6.5.8.1)is set to [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

227/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.66 HDRSmoothing** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD132|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x0003 [Normal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “HDR (high dynamic range) – Smoothing” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0002|Low|
|0x0003|Normal|
|0x0004|High|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The EnableBracketing property (subsection 6.5.8.1) is set to [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

228/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.67 HDRSaveIndividualImages** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD133|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “HDR (high dynamic range) – Save individual images (RAW)” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The EnableBracketing property (subsection 6.5.8.1) is set to [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

229/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.2.68 SilentPhotography** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1AD|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Silent shooting” in the photo shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



Do Not Copy 

230/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3 Vendor (Movie Shooting Menu)** 

## **6.5.3.1 MovieRecordDestination** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0A3|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|DefaultValue|1[Slot1]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Destination” in the movie shooting menu. 

If a card is not inserted in the slot that is set in this property, the movie is recorded on the card that is inserted in the other slot. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|Slot 1|
|2|Slot2|



Do Not Copy 

231/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.2 MovieCaptureAreaCrop** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD20F|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [FX]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Choose image area” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|FX|
|2|DX|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|DX lensismounted onthe camera.|
||The MovieRecordScreenSize property (subsection 6.5.3.3) is set to<br>[3840x2160 60p], [3840x2160 50p], [1920x1080 120p] , [1920x1080<br>100p] or[Slow].|



Do Not Copy 

232/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.3 MovieRecordScreenSize** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0A0|
|DataType|UINT64|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x07800438003C0000 [1920×1080 60p]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Image size/frame rate” in the movie shooting menu. 

## ○ **Property Details** 

## The following values are assigned to each bit of Property Value. 

|Bit|Bit number|Description|
|---|---|---|
|48-63|16|Horizontal resolution|
|32-47|16|Vertical resolution|
|24-31|8|Reserved (0)|
|16-23|8|Frame rate|
|14-15|2|Scan type|
|8-13|6|Special shooting|
|0-7|8|Special shooting supplementary information|



Horizontal resolution / Vertical resolution / Frame rate 

The resolution or frame rate values are assigned. 

Scan type 

|Value|Description|
|---|---|
|0|p (Progressive)|
|1|i (Interlace)|
|From 2to 3|Reserved|



Special shooting 

|Value|Description|
|---|---|
|0|Normal|
|1|Slow-motion|
|2|Crop|
|From 3 to 63|Reserved|



Special shooting supplementary information 

If there is no supplementary information, it is fixed to 0. In the case of slow motion, the value is 10 times the slow magnification. 

|Value|Description|
|---|---|
|40|x4 slow-motion|
|50|x5 slow-motion|



Do Not Copy 

233/484 

**Confidential** 

## **Confidential** 

## **Nikon Corporation** 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0x0F000870003C0000|3840×2160 60p|
|0x0F00087000320000|3840×2160 50p|
|0x0F000870001E0000|3840×2160 30p|
|0x0F00087000190000|3840×2160 25p|
|0x0F00087000180000|3840×2160 24p|
|0x0780043800780000|1920×1080 120p|
|0x0780043800640000|1920×1080 100p|
|0x07800438003C0000|1920×1080 60p|
|0x0780043800320000|1920×1080 50p|
|0x07800438001E0000|1920×1080 30p|
|0x0780043800190000|1920×1080 25p|
|0x0780043800180000|1920×1080 24p|
|0x07800438001E0128|1920×1080 30p4-times slow|
|0x0780043800190128|1920×1080 25p4-times slow|
|0x0780043800180132|1920×1080 24p5-times slow|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|During storing movie frame.|
||[1920×1080 120p], [1920×1080 100p] or [Slow] is set when a DX lens<br>is mounted.|
||[3840×2160<br>60p]<br>or<br>[3840×2160<br>50p]<br>is<br>set<br>when<br>the<br>HDMIOutputDataDepth property (subsection 6.5.5.12) is set to [10 bits]<br>and the camerais connectedwith HDMI.|



Do Not Copy 

234/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.4 MovieRecordQuality** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0A7|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [High quality]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Movie quality” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|High quality|
|1|Normal|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The MovieRecordScreenSize property (subsection 6.5.3.3) is set to<br>[3840x2160], [1920×1080120p], [1920×1080100p] or[Slow].|



Do Not Copy 

235/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.5 MovieFileType** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0AF|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [MOV]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Movie file type” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|MOV|
|1|MP4|



Do Not Copy 

236/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.6 MovieISOAutoHighLimit** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0AE|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|51200 [ISO 51200]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Movie ISO sensitivity settings – Maximum sensitivity” in the movie shooting menu. 

## ○ **Property Details** 

When the following conditions are satisfied, the minimum value and maximum value for Movie ISO sensitivity are limited.  The setting effective range can be confirmed in the descriptor of this property. 

No Condition 1 The MovieLogOutput property (subsection 6.5.7.27) is [On]. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Maximum sensitivity|Maximum sensitivity|ExposureEVStep|ExposureEVStep|ExposureEVStep|
|---|---|---|---|---|
|Property Value|Description|1/3 step|1/2 step|1 step|
|200|200|`✓`|`✓`|`✓`|
|250|250|`✓`|-|-|
|280|280|-|`✓`|-|
|320|320|`✓`|-|-|
|400|400|`✓`|`✓`|`✓`|
|500|500|`✓`|-|-|
|560|560|-|`✓`|-|
|640|640|`✓`|-|-|
|800|800|`✓`|`✓`|`✓`|
|1000|1000|`✓`|-|-|
|1100|1100|-|`✓`|-|
|1250|1250|`✓`|-|-|
|1600|1600|`✓`|`✓`|`✓`|
|2000|2000|`✓`|-|-|
|2200|2200|-|`✓`|-|
|2500|2500|`✓`|-|-|
|3200|3200|`✓`|`✓`|`✓`|
|4000|4000|`✓`|-|-|
|4500|4500|-|`✓`|-|
|5000|5000|`✓`|-|-|
|6400|6400|`✓`|`✓`|`✓`|
|8000|8000|`✓`|-|-|
|9000|9000|-|`✓`|-|
|10000|10000|`✓`|-|-|
|12800|12800|`✓`|`✓`|`✓`|
|16000|16000|`✓`|-|-|
|18000|18000|-|`✓`|-|
|20000|20000|`✓`|-|-|
|25600|25600|`✓`|`✓`|`✓`|
|32000|32000|`✓`|-|-|
|36000|36000|-|`✓`|-|
|40000|40000|`✓`|-|-|
|51200|51200|`✓`|`✓`|`✓`|



Do Not Copy 

237/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

|||||**Nikon**|
|---|---|---|---|---|
|64000|Hi 0.3|`✓`|-|-|
|72000|Hi 0.5|-|`✓`|-|
|81200|Hi 0.7|`✓`|-|-|
|102400|Hi 1.0|`✓`|`✓`|`✓`|
|204800|Hi 2.0|`✓`|`✓`|`✓`|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

Response Code Description The ExposureProgramMode property (subsection 6.5.1.11) is set to Access_Denied anything other than PSAM. 

Do Not Copy 

238/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.7 MovieISOAutoControl** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0AD|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|1 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Movie ISO sensitivity settings – Auto ISO control (mode M)” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than M during movie recording.|



Do Not Copy 

239/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.8 MovieExposureIndex** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1AA|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|100 [ISO100]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Movie ISO sensitivity settings – ISO sensitivity (mode M)” in the movie shooting menu. 

## ○ **Property Details** 

When the following conditions are satisfied, the minimum value and maximum value for Movie ISO sensitivity are limited.  The setting effective range can be confirmed in the descriptor of this property. 

No Condition 1 The MovieLogOutput property (subsection 6.5.7.27) is [On]. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

The property value changes depending on the setting of the ExposureEVStep property (subsection 6.5.4.6). 

|Property Value|Description|ExposureEVStep|ExposureEVStep|ExposureEVStep|
|---|---|---|---|---|
|||1/3<br>step|1/2<br>step|1 step|
|100|100|`✓`|`✓`|`✓`|
|125|125|`✓`|-|-|
|140|140|-|`✓`|-|
|160|160|`✓`|-|-|
|200|200|`✓`|`✓`|`✓`|
|250|250|`✓`|-|-|
|280|280|-|`✓`|-|
|320|320|`✓`|-|-|
|400|400|`✓`|`✓`|`✓`|
|500|500|`✓`|-|-|
|560|560|-|`✓`|-|
|640|640|`✓`|-|-|
|800|800|`✓`|`✓`|`✓`|
|1000|1000|`✓`|-|-|
|1100|1100|-|`✓`|-|
|1250|1250|`✓`|-|-|
|1600|1600|`✓`|`✓`|`✓`|
|2000|2000|`✓`|-|-|
|2200|2200|-|`✓`|-|
|2500|2500|`✓`|-|-|
|3200|3200|`✓`|`✓`|`✓`|
|4000|4000|`✓`|-|-|
|4500|4500|-|`✓`|-|
|5000|5000|`✓`|-|-|
|6400|6400|`✓`|`✓`|`✓`|
|8000|8000|`✓`|-|-|
|9000|9000|-|`✓`|-|
|10000|10000|`✓`|-|-|
|12800|12800|`✓`|`✓`|`✓`|



Do Not Copy 

240/484 

**Confidential** 

**Confidential** 

## **Nikon Corporation** 

|||||**Niko**|
|---|---|---|---|---|
|16000|16000|`✓`|-|-|
|18000|18000|-|`✓`|-|
|20000|20000|`✓`|-|-|
|25600|25600|`✓`|`✓`|`✓`|
|32000|32000|`✓`|-|-|
|36000|36000|-|`✓`|-|
|40000|40000|`✓`|-|-|
|51200|51200|`✓`|`✓`|`✓`|
|64000|Hi 0.3|`✓`|-|-|
|72000|Hi 0.5|-|`✓`|-|
|81200|Hi 0.7|`✓`|-|-|
|102400|Hi 1.0|`✓`|`✓`|`✓`|
|204800|Hi 2.0|`✓`|`✓`|`✓`|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan Mduringmovierecording.|



Do Not Copy 

241/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.9 MovieWhiteBalance** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD23A|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x8015 [Same as photo settings]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “White Balance” in the movie shooting menu. 

## ○ **Property Details** 

When the property value is set to [Same as photo settings], the white balance value that is set in the WhiteBalance (6.5.1.4) is applied to the movie white balance.  In this case, the photo white balance setting is used for movie setting as in the following table. 

|Item|Property|
|---|---|
|Auto-Type|WbAutoType(6.5.2.14)|
|Auto-FineTune|WbTuneAuto(6.5.2.15)|
|Incandescent-FineTune|WbTuneIncandescent(6.5.2.20)|
|Fluorescent- Type|WbFluorescentType(6.5.2.21)|
|Fluorescent-FineTune|WbTuneFluorescent(6.5.2.22)|
|Sunny-FineTune|WbTuneSunny(6.5.2.17)|
|Flash-FineTune|WbTuneFlash(6.5.2.23)|
|Cloudy-FineTune|WbTuneCloudy(6.5.2.18)|
|Shade- FineTune|WbTuneShade(6.5.2.19)|
|Choose color temp-Value|WbColorTemp(6.5.2.24)|
|Choose colortemp- FineTune|WbTuneColorTemp(6.5.2.25)|
|Natural light auto-FineTune|WbTuneNatural(6.5.2.16)|
|Preset manual|WbPresetDataNo(6.5.2.26)|
|Preset manual-D1-Comment|WbPresetDataComment1(6.5.2.27)|
|Preset manual-D2-Comment|WbPresetDataComment2(6.5.2.28)|
|Presetmanual-D3-Comment|WbPresetDataComment3(6.5.2.29)|
|Preset manual-D4-Comment|WbPresetDataComment4(6.5.2.30)|
|Preset manual-D5-Comment|WbPresetDataComment5(6.5.2.31)|
|Preset manual-D6-Comment|WbPresetDataComment6(6.5.2.32)|
|Preset manual-D1-Data|WbPresetDataValue1(6.5.2.33)|
|Presetmanual-D2- Data|WbPresetDataValue2(6.5.2.34)|
|Preset manual-D3-Data|WbPresetDataValue3(6.5.2.35)|
|Preset manual-D4-Data|WbPresetDataValue4(6.5.2.36)|
|Preset manual-D5-Data|WbPresetDataValue5(6.5.2.37)|
|Preset manual-D6-Data|WbPresetDataValue6(6.5.2.38)|
|Presetmanual-D1- FineTune|WbTunePreset1(6.5.2.39)|
|Preset manual-D2-FineTune|WbTunePreset2(6.5.2.40)|
|Preset manual-D3-FineTune|WbTunePreset3(6.5.2.41)|
|Preset manual-D4-FineTune|WbTunePreset4(6.5.2.42)|
|Preset manual-D5-FineTune|WbTunePreset5(6.5.2.43)|
|Presetmanual-D6- FineTune|WbTunePreset6(6.5.2.44)|
|Preset manual-D1-Protect|WbPresetProtect1(6.5.2.45)|
|Presetmanual-D2- Protect|WbPresetProtect2(6.5.2.46)|
|Preset manual-D3-Protect|WbPresetProtect3(6.5.2.47)|
|Preset manual-D4-Protect|WbPresetProtect4(6.5.2.48)|
|Preset manual-D5-Protect|WbPresetProtect5(6.5.2.49)|
|Preset manual-D6-Protect|WbPresetProtect6(6.5.2.50)|



Do Not Copy 

242/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0x0002|Auto|
|0x0004|Sunny|
|0x0005|Fluorescent|
|0x0006|Incandescent|
|0x8010|Cloudy|
|0x8011|Shade|
|0x8012|Choose color temp.|
|0x8013|Preset manual|
|0x8015|Same as photo settings|
|0x8016|Natural light auto|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|
||[Same as photo settings] was set during movie recording.|



Do Not Copy 

243/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.10 MovieWbAutoType** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD211|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Keep overall atmosphere]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the type of “White balance - Auto” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Keep overall atmosphere|
|1|Keep warm lighting colors|
|2|Keep white|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



## **6.5.3.11 MovieWbTuneAuto** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD212|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance - Auto” in the movie shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] duringmovierecording.|



Do Not Copy 

244/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.12 MovieWbTuneNatural** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD23C|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance – Natural light auto” in the movie shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



## **6.5.3.13 MovieWbTuneSunny** 

## ○ **Property Specifications** 

|Property Code|0xD216|
|---|---|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|PropertyValue|From0 to1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance – Direct sunlight” in the movie shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] duringmovierecording.|



Do Not Copy 

245/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.14 MovieWbTuneCloudy** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD218|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance - Cloudy” in the movie shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] duringmovierecording.|



## **6.5.3.15 MovieWbTuneShade** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD219|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance – Shade” in the movie shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



Do Not Copy 

246/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.16 MovieWbTuneIncandescent** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD213|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance - Incandescent” in the movie shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



## **6.5.3.17 MovieWbFluorescentType** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD214|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|3 [White fluorescent lamp]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the light source of “White balance - Fluorescent” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Sodium lamp mixed light|
|1|Cool whitefluorescentlamp|
|2|Warm white fluorescent lamp|
|3|White fluorescent lamp|
|4|Day white fluorescent lamp|
|5|Daylight fluorescent lamp|
|6|Highcolor-temperaturemercurylamp|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



Do Not Copy 

247/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.18 MovieWbTuneFluorescent** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD215|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance - Fluorescent” in the movie shooting menu. For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] duringmovierecording.|



Do Not Copy 

248/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.19 MovieWbColorTemp** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD21A|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|5000 [K]|
|Property Value|From 2500 K to 10000 K (increase or decrease in units of 10 K)|



## ○ **Property Outline** 

Indicates the color temperature (K) of “White balance – Choose color temp.” in the movie shooting menu. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] duringmovierecording.|



## **6.5.3.20 MovieWbTuneColorTemp** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD21B|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|24|
|Property Value|From 0 to 48|



## ○ **Property Outline** 

Indicates the fine tuning volume of “White balance – Choose color temp.” in the movie shooting menu. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



Do Not Copy 

249/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.21 MovieWbPresetDataNo** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD21C|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|1 [d-1]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “White balance – Preset manual” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|d-1|
|2|d-2|
|3|d-3|
|4|d-4|
|5|d-5|
|6|d-6|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



Do Not Copy 

250/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.22 MovieWbPresetDataComment1** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD21D|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-1” in the movie shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|
|Access_Denied|TheMovieWbPresetProtect1property (subsection6.5.3.40)is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



## **6.5.3.23 MovieWbPresetDataComment2** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD21E|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|PropertyValue|(Depends onthe usersetting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-2” in the movie shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|Astring exceeding 36 charactersis set.|
|Access_Denied|The MovieWbPresetProtect2 property (subsection 6.5.3.41) is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

251/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.24 MovieWbPresetDataComment3** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD21F|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-3” in the movie shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|
|Access_Denied|TheMovieWbPresetProtect3 property (subsection6.5.3.42)is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



## **6.5.3.25 MovieWbPresetDataComment4** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD220|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|PropertyValue|(Depends onthe usersetting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-4” in the movie shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|Astring exceeding 36 charactersis set.|
|Access_Denied|The MovieWbPresetProtect4 property (subsection 6.5.3.43) is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

252/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.26 MovieWbPresetDataComment5** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD221|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-5” in the movie shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|
|Access_Denied|TheMovieWbPresetProtect5 property (subsection6.5.3.44)is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



## **6.5.3.27 MovieWbPresetDataComment6** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD222|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|36 characters of spaces (0x20)|
|PropertyValue|(Depends onthe usersetting)|



## ○ **Property Outline** 

Indicates the comment of “White balance – Preset manual – d-6” in the movie shooting menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). When the string is shorter than 36 characters, the shortage is padded with spaces (0x20). For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|Astring exceeding 36 charactersis set.|
|Access_Denied|The MovieWbPresetProtect6 property (subsection 6.5.3.45) is [On].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

253/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.28 MovieWbPresetDataValue1** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD223|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-1” in the movie shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

## **6.5.3.29 MovieWbPresetDataValue2** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD224|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-2” in the movie shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

## **6.5.3.30 MovieWbPresetDataValue3** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD225|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-3” in the movie shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

Do Not Copy 

254/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.31 MovieWbPresetDataValue4** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD226|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-4” in the movie shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

## **6.5.3.32 MovieWbPresetDataValue5** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD227|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-5” in the movie shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

## **6.5.3.33 MovieWbPresetDataValue6** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD228|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x08000800 [Rgain: 1.0, Bgain: 1.0]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates the white balance data of “White balance – Preset manual – d-6” in the movie shooting menu. 

## ○ **Property Details** 

Refer to PreWbGainValue in SetPreWbData (subsection 6.2.2.42) about the format of the PropertyValue. 

Do Not Copy 

255/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.34 MovieWbTunePreset1** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD229|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-1” in the movie shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheMovieWbPresetProtect1property (subsection6.5.3.40)is [On].|
||The MovieWbPresetDataNo property (subsection 6.5.3.21) is set to<br>anything other than [d-1].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] duringmovierecording.|



## **6.5.3.35 MovieWbTunePreset2** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD22A|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-2” in the movie shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The MovieWbPresetProtect2 property (subsection 6.5.3.41) is [On].|
||The MovieWbPresetDataNo property (subsection 6.5.3.21) is set to<br>anything other than [d-2].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



Do Not Copy 

256/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.36 MovieWbTunePreset3** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD22B|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-3” in the movie shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheMovieWbPresetProtect3 property (subsection6.5.3.42)is [On].|
||The MovieWbPresetDataNo property (subsection 6.5.3.21) is set to<br>anything other than [d-3].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] duringmovierecording.|



## **6.5.3.37 MovieWbTunePreset4** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD22C|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-4” in the movie shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The MovieWbPresetProtect4 property (subsection 6.5.3.43) is [On].|
||The MovieWbPresetDataNo property (subsection 6.5.3.21) is set to<br>anything other than [d-4].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



Do Not Copy 

257/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.38 MovieWbTunePreset5** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD22D|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-5” in the movie shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheMovieWbPresetProtect5 property (subsection6.5.3.44)is [On].|
||The MovieWbPresetDataNo property (subsection 6.5.3.21) is set to<br>anything other than [d-5].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] duringmovierecording.|



## **6.5.3.39 MovieWbTunePreset6** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD22E|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|612|
|Property Value|From 0 to 1224|



## ○ **Property Outline** 

Indicates the white balance fine tuning volume of “White balance – Preset manual – d-6” in the movie shooting menu. 

For the details of the fine tuning volume, refer to subsection 11.5. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The MovieWbPresetProtect6 property (subsection 6.5.3.45) is [On].|
||The MovieWbPresetDataNo property (subsection 6.5.3.21) is set to<br>anything other than [d-6].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieWhiteBalance property (subsection 6.5.3.9) is set to [Same<br>as photo settings] during movie recording.|



Do Not Copy 

258/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.40 MovieWbPresetProtect1** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD22F|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-1” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



## **6.5.3.41 MovieWbPresetProtect2** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD230|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-2” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

259/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.42 MovieWbPresetProtect3** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD231|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-3” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



## **6.5.3.43 MovieWbPresetProtect4** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD232|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-4” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

260/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.44 MovieWbPresetProtect5** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD233|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-5” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



## **6.5.3.45 MovieWbPresetProtect6** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD234|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

Indicates the protection of “White balance – Preset manual – d-6” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

261/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.46 MovieActive-D-Lighting** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD23B|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x0000 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Active D-Lighting” in the movie shooting menu. 

## ○ **Property Details** 

When this is set to [Same as photo settings], the current value of the Active-D-Lighting property (subsection 6.5.2.52) is used in this property.  If the Active-D-Lighting property is set to [Auto], this property is set to [Normal]. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Off|
|0x0002|Low|
|0x0003|Normal|
|0x0004|High|
|0x0005|Extra high|
|0x0064|Same as photo settings|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The MovieLogOutput property (subsection 6.5.7.27) is [On].|



Do Not Copy 

262/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.47 MovieNoiseReductionHiIso** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD236|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x0003 [Normal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “High ISO NR” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Off|
|0x0002|Low|
|0x0003|Normal|
|0x0004|High|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheMovieLogOutput property (subsection6.5.7.27)is [On].|



Do Not Copy 

263/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.48 MovieVignetteControl** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD23E|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x003 [Normal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Vignette control” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Off|
|0x0002|Low|
|0x0003|Normal|
|0x0004|High|
|0x0064|Same as photo settings|



Do Not Copy 

264/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.49 MovieDiffractionCompensation** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD23F|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|1 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Diffraction compensation” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



Do Not Copy 

265/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.50 MovieAutoDistortion** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0BC|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|1 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Auto distortion control” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The LensTypeML property (subsection 6.5.10.2) is set to [Lens whose<br>automatic distortion correction is alwayseffective].|



Do Not Copy 

266/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.51 DecreaseFlicker** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD034|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0xFF [Auto]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the setting of “Flicker reduction” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x00|50 Hz|
|0x01|60 Hz|
|0xFF|Auto|



Do Not Copy 

267/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.52 MovieExposureMeteringMode** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1AF|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x0003 [Matrix metering]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the setting of “Exposure metering mode” in the movie live view. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0002|Center-weighted metering|
|0x0003|Matrix metering|
|0x8010|Highlight-weighted metering|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The AELockStatus property (subsection 6.5.7.8) is [Locked].|



Do Not Copy 

268/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.53 MovieFocusMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1FA|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|2 [AF-F]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Focus mode” in movie shooting. 

## ○ **Property Details** 

If the following conditions are satisfied, it operates with MF mode even when this property is set to AF. 

- CPU lens is not mounted. - The switches on the camera or lens are set to MF. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

**==> picture [234 x 56] intentionally omitted <==**

**----- Start of picture text -----**<br>
Property Value Description<br>0  AF-S<br>1  AF-C<br>2  AF-F<br>4  MF<br>**----- End of picture text -----**<br>


Do Not Copy 

269/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.54 MovieFocusMeteringMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1F8|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x8020 [Auto-area AF (Person)]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “AF-area mode” in movie shooting. 

## ○ **Property Details** 

In the following cases, this property is set to the single-point AF mode. When the following state is canceled without changing the AF area mode, it returns to the AF area mode which was set immediately before. 

- In the case that the MovieFocusMode property (subsection 6.5.3.53) is [MF]. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

The value of PropertyValue changes depending on the value of the movie focus mode. 

|Property|||Movie focus|mode setting||
|---|---|---|---|---|---|
|<br>Value|Description|MF|AF-S|AF-C|AF-F|
|0x8010|Single-point AF mode|`✓`|`✓`|`✓`|`✓`|
|0x8011|Auto-area AF mode|-|`✓`|`✓`|`✓`|
|0x8018|Wide-area AF(S)|-|`✓`|`✓`|`✓`|
|0x8019|Wide-area AF(L)|-|`✓`|`✓`|`✓`|
|0x801A|Wide-area AF(L - Person)|-|`✓`|`✓`|`✓`|
|0x801B|Wide-area AF(L - Animal)|-|`✓`|`✓`|`✓`|
|0x8020|Auto-area AF(Person)|-|`✓`|`✓`|`✓`|
|0x8021|Auto-area AF(Animal)|-|`✓`|`✓`|`✓`|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The movie focus mode is set to the manual focus.<br>NOTE) Except when the focus mode is set to MF due to the CPU lens<br>not attached or the operation with the camera dial/switch.|



Do Not Copy 

270/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.55 MovieVibrationReduction** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1F9|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|100 [Same as photo settings]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the setting of “Vibration reduction” in the movie shooting menu. 

## ○ **Property Details** 

The supported value changes depending on the type of mounted lens. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

When the lens anti- vibration mode is [Normal] or [Sports]: 

|Property Value|Description|
|---|---|
|0|Off|
|1|Normal|
|2|Sports|
|100|Same as photo settings|



## When the lens anti- vibration mode is only [Normal]: 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|
|100|Same as photo settings|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The mounted lens has VR switch.|
||The VR lens is not mounted.|



Do Not Copy 

271/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.56 ElectronicVR** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD314|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the setting of “Electronic VR” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The MovieRecordScreenSize property (subsection 6.5.3.3) is set to<br>[3840 x 2160 60p], [3840 x 2160 50p], [1920 x 1080 120p] , [1920 x<br>1080 100p] or [Slow].|



Do Not Copy 

272/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.57 MovieRecordMicrophoneLevel** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0A2|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Auto sensitivity]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Microphone sensitivity” in the movie shooting menu. 

## ○ **Property Details** 

Switching between [Auto sensitivity/Manual sensitivity] and [Microphone off] cannot be performed during movie recording. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Auto sensitivity|
|1|Manual sensitivity|
|2|Microphone off|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|[Microphone off] is set during movie recording.|
||[Microphone off] is set while [Auto sensitivity] or [Manual sensitivity] is<br>specified during movie recording.|
||The MovieRecordScreenSize property (subsection 6.5.3.3) is set to<br>[Slow].|



Do Not Copy 

273/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.58 MovieRecordMicrophoneLevelValue** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0A8|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|15|
|Property Value|From 1 to 20|



## ○ **Property Outline** 

Indicates the microphone sensitivity of “Microphone sensitivity – Manual sensitivity” in the movie shooting menu. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The MovieRecordMicrophoneLevel property (subsection 6.5.3.57) is<br>set to anything other than [Manual sensitivity].|
||The MovieRecordScreenSize property (subsection 6.5.3.3) is set to<br>[Slow].|



Do Not Copy 

274/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.59 MovieAttenuator** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD23D|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Attenuator” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The MovieRecordMicrophoneLevel property (subsection 6.5.3.57) is<br>set to [Microphone off] during movie recording.|
||The MovieRecordScreenSize property (subsection 6.5.3.3) is set to<br>[Slow].|



Do Not Copy 

275/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.60 MovieRecordingZone** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0AC|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Wide range]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Frequency response” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Wide range|
|1|Vocal range|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The MovieRecordMicrophoneLevel property (subsection 6.5.3.57) is<br>set to [Microphone off] during movie recording.|
||The MovieRecordScreenSize property (subsection 6.5.3.3) is set to<br>[Slow].|



Do Not Copy 

276/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.61 MovieWindNoiseReduction** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0AA|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Wind noise reduction” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|Anexternal microphoneis connected.|
||The MovieRecordMicrophoneLevel property (subsection 6.5.3.57) is<br>set to [Microphone off] during movie recording.|
||The MovieRecordScreenSize property (subsection 6.5.3.3) is set to<br>[Slow].|



Do Not Copy 

277/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.62 RecordTimeCodes** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1FB|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Time codes – Recording time codes” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|
|2|On (with HDMI external output)|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|During time not set warning.|



Do Not Copy 

278/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.63 CountUpMethod** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1FC|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Rec Run]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Time codes – Count up method” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Rec Run|
|1|Free Run|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheRecordTimeCodes property (subsection6.5.3.62)is set to [Off].|
||During time not set warning.|



Do Not Copy 

279/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.64 TimeCodeOrigin** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1FD|
|DataType|AUINT8|
|Description form|None|
|Get / Set|Get, Get / Set|
|Default Value|Array[0]：2 [Current time]<br>From Array[1]to[4]：0|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

Indicates “Time codes – Time code origin” in the movie shooting menu. 

## ○ **Property Details** 

If Array[0] (Time code origin nformation) is set to the value other than 1 (Manual input), it is as follows. 

|Get/Set|Description|
|---|---|
|Get operation|The values from Array[1] to Array[4] are not fixed.|
|Set operation|Anyvalues setfrom Array[1] toArray[4] areignored.|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|Description|
|---|---|---|
|NumElement|Time code origin nformation,Number of elements<br>of time||
|Array[0]|Time code origin nformation||
||0|Reset|
||1|Manual input|
||2|Current time|
|Array[1]|Hour (From 00 to 23)||
|Array[2]|Minute (From00 to 59)||
|Array[3]|Second (From 00 to 59)||
|Array[4]|Frame *1<br>24fps (From 00 to 23)<br>25/50/100fps (From 00 to 24)<br>30/60/120fps (From 00 to 29)||



*1 The range of the settable value changes depending on the frame rate of the 

MovieRecordScreenSize property (subsection 6.5.3.3). 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The RecordTimeCodes property (subsection 6.5.3.62) is set to [Off].|
||During time not set warning.|



Do Not Copy 

280/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.3.65 DropFrame** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1FE|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|1 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Time codes – Drop frame” in the movie shooting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheRecordTimeCodes property (subsection6.5.3.62)is set to [Off].|
||During time not set warning.|



Do Not Copy 

281/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4 Vendor (Custom Setting Menu)** 

## **6.5.4.1 DynamicAFonAFC** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD048|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|DefaultValue|0 [Release]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Autofocus – AF-C priority selection” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|Release|
|3|Focus|



Do Not Copy 

282/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.2 DynamicAFonAFS** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD049|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|3 [Focus]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Autofocus – AF-S priority selection” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Release|
|3|Focus|



Do Not Copy 

283/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.3 AFStillLockOnAcross** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD046|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|3|
|Property Value|From 1 [High sensitivity] to 5 [Low sensitivity]|



## ○ **Property Outline** 

Indicates “Autofocus – Focus tracking with lock-on – Across” in the custom setting menu. 

Do Not Copy 

284/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.4 EnableAFAreaPoint** 

- **Property Specifications** 

|**Property Specificationsperty Specificationserty Specificationsy Specifications Specificationspecificationsecifications**||
|---|---|
|Property Code|0xD08D|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [All points]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Autofocus – Number of focus points” in the custom setting menu. 

## ○ **Property Details** 

If the selected focus point is not included in the skip when the focus points are switched from all points to skip, the selected focus point is changed automatically. 

A change pattern of focus points is shown below. 

The focus points on the left figure (All points) are changed to the focus points on the right figure (Skip). 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|All points|
|1|Skip|



Do Not Copy 

285/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.5 LowLightAF** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD17A|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Autofocus – Low light AF” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

286/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.6 ExposureEVStep** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD056|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|2 [1/3 step]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Metering/exposure – EV steps for exposure cntrl” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|2|1/3 step|
|3|1/2 step|
|6|1 step|



Do Not Copy 

287/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.7 CenterWeightedExRange** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD059|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x0C [Φ12 mm]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Metering/exposure – Center-weighted area” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0C|Φ12 mm|
|0xFF|Average|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

288/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.8 ExposureBaseCompMatrix** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD05A|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [0.0 EV]|
|Property Value|From-6 [-1.0 EV] to+6 [+1.0 EV]|



## ○ **Property Outline** 

Indicates “Metering/exposure – Fine-tune optimal exposure - Matrix metering” in the custom setting menu. 

## **6.5.4.9 ExposureBaseCompCenter** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD05B|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [0.0 EV]|
|PropertyValue|From -6 [-1.0EV] to+6 [+1.0EV]|



## ○ **Property Outline** 

Indicates “Metering/exposure – Fine-tune optimal exposure - Center-weighted metering” in the custom setting menu. 

## **6.5.4.10 ExposureBaseCompSpot** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD05C|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [0.0 EV]|
|PropertyValue|From -6 [-1.0EV] to+6 [+1.0EV]|



## ○ **Property Outline** 

Indicates “Metering/exposure – Fine-tune optimal exposure - Spot metering” in the custom setting menu. 

## **6.5.4.11 ExposureBaseCompHighlight** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD239|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [0.0 EV]|
|PropertyValue|From -6 [-1.0EV] to+6 [+1.0EV]|



## ○ **Property Outline** 

Indicates “Metering/exposure – Fine-tune optimal exposure - Highlight-weighted metering” in the custom setting menu. 

Do Not Copy 

289/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.12 CSpeedLow** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD068|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|3 [3 fps]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Shooting/display – Continuous shooting speed – Continuous low-speed” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|1 fps|
|2|2 fps|
|3|3fps|
|4|4 fps|
|5|5fps|



Do Not Copy 

290/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.13 BurstMaxNumber** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD069|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|200 [200 frames]|
|Property Value|From 1 [One frame] to 200 [200 frames]|



## ○ **Property Outline** 

Indicates “Shooting/display – Max. continuous release” in the custom setting menu. 

Do Not Copy 

291/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.14 ExposureDelay** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD06A|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Shooting/display – Exposure delay mode” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|2|0.2 s|
|5|0.5 s|
|10|1s|
|20|2 s|
|30|3 s|



Do Not Copy 

292/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.15 ElectronicFrontCurtainShutter** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD20D|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|2 [Auto]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Shooting/display – Electronic Front-Curtain Shutter” in the custom setting menu. 

## ○ **Property Details** 

If the camera is equipped with a lens for which a mechanical shutter cannot be set, "mechanical shutter" is not listed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Mechanicalshutter|
|1|Electronic front curtain shutter|
|2|Auto|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The SilentPhotography property (subsection 6.5.2.68) is set to [On].|



Do Not Copy 

293/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.16 ExtendedShutterSpeedsManual** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD16E|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Shooting/display – Extended Shutter Speed (M)” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



Do Not Copy 

294/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.17 NumberingMode** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD06C|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|1 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Shooting/display – File number sequence” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|TheHDRMode property (subsection6.5.2.64)is set to [On].|



Do Not Copy 

295/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.18 ApplyLiveViewSetting** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD17B|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|1 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Shooting/display – Apply settings to live view” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



Do Not Copy 

296/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.19 DetectionPeaking** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1B9|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Focus peaking – Peaking detection” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|Low|
|2|Normal|
|3|High|



Do Not Copy 

297/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.20 FlashSyncSpeed** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD074|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x000100C8 [1/200 s]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Bracketing/flash – Flash sync speed” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x800100C8|1/200 s (auto FP)|
|0x000100C8|1/200 s|
|0x000100A0|1/160 s|
|0x0001007D|1/125 s|
|0x00010064|1/100 s|
|0x00010050|1/80 s|
|0x0001003C|1/60 s|



Do Not Copy 

298/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.21 FlashSlowSpeedLimit** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD075|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x0001003C [1/60 s]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Bracketing/flash – Flash shutter speed” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0001003C|1/60 s|
|0x0001001E|1/30 s|
|0x0001000F|1/15 s|
|0x00010008|1/8 s|
|0x00010004|1/4 s|
|0x00010002|1/2 s|
|0x00010001|1 s|
|0x00020001|2 s|
|0x00040001|4s|
|0x00080001|8 s|
|0x000F0001|15 s|
|0x001E0001|30 s|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

299/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.22 ExposureCompFlashUsed** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD118|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Entire frame]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Bracketing/flash – Exposure comp. for flash” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Entire frame|
|1|Background only|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

300/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.23 AutoFlashIsoSensitivityControl** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1C5|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Subject and background]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Bracketing/flash – Auto Flash ISO Sensitivity Control” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Subject and background|
|1|Subject only|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

301/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.24 SelectBracketChangeFactor** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD079|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Flash/speed]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Bracketing/flash – Auto bracketing (mode M)” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Flash/speed|
|1|Flash/speed/aperture|
|2|Flash/aperture|
|3|Flashonly|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

302/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.25 BracketingOrder** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD07A|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [[0]->[-]->[+]]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Bracketing/flash – Bracketing order” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|[0]->[-]->[+]|
|1|[-]->[0]->[+]|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

303/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.26 TVLockSetting** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD112|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Controls – Shutter spd & aperture lock – Shutter speed lock” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan[S] or[M].|
||Error / warning displayed on shutter speed or aperture value display.<br>(Either the shutter speed or aperture value turns off)|
||Onthe card unformatted error.|
||Attached a lens that failed firmware upgrade.|



Do Not Copy 

304/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.27 AVLockSetting** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD113|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Controls – Shutter spd & aperture lock – Aperture lock” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|AAccess_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than [S], [A] or [M].|
||Error / warning displayed on shutter speed or aperture value display.<br>(Eitherthe shutterspeed oraperturevalue turns off)|
||On the card unformatted error.|
||Attached a lens that failed firmware upgrade.|
||A mount adapter is attached.|



Do Not Copy 

305/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.28 MovieReleaseButton** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD197|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Take photos]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Movie – Assign custom button – Shutter button” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Take photos|
|1|Record movies|



Do Not Copy 

306/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.29 MovieAfSpeed** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD17C|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0|
|Property Value|From-5[Low speed] to 5[High speed]|



## ○ **Property Outline** 

Indicates “Movie – AF speed” in the custom setting menu. 

Do Not Copy 

307/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.30 MovieAfSpeedWhenToApply** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD17D|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Always]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Movie – AF speed – When to apply” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Always|
|1|Only while recording|



Do Not Copy 

308/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.31 MovieAfTrackingSensitivity** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD17E|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|4|
|Property Value|From 1 [High sensitivity] to 7 [Low sensitivity]|



## ○ **Property Outline** 

Indicates “Movie – AF tracking sensitivity” in the custom setting menu. 

Do Not Copy 

309/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.4.32 HighlightBrightness** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1DF|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x00F8 [248]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Movie – Highlight - Brightness setting on the highlight” in the custom setting menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x00B4|180|
|0x00BF|191|
|0x00CA|202|
|0x00D5|213|
|0x00E0|224|
|0x00EB|235|
|0x00F8|248|
|0x00FF|255|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

310/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5 Vendor (Setup Menu)** 

## **6.5.5.1 ManualSettingLensNo** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD093|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|DefaultValue|0 [No.1]|
|Property Value|From 0 [No. 1] to 19 [No. 20]|



## ○ **Property Outline** 

Indicates “Non-CPU lens data – Lens number” in the setup menu. 

Do Not Copy 

311/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.2 FmmManualSetting** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD02E|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Not set]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Non-CPU lens data – Focal length (mm)” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Not set|
|6|6mm|
|8|8mm|
|13|13mm|
|15|15mm|
|16|16mm|
|18|18mm|
|20|20mm|
|24|24mm|
|25|25mm|
|28|28mm|
|35|35mm|
|43|43mm|
|45|45mm|
|50|50mm|
|55|55mm|
|58|58mm|
|70|70mm|
|80|80mm|
|85|85mm|
|86|86mm|
|100|100mm|
|105|105mm|
|135|135mm|
|180|180mm|
|200|200mm|
|300|300mm|
|360|360mm|
|400|400mm|
|500|500mm|
|600|600mm|
|800|800mm|
|1000|1000mm|
|1200|1200mm|
|1400|1400mm|
|1600|1600mm|
|2000|2000mm|
|2400|2400mm|
|2800|2800mm|
|3200|3200mm|
|4000|4000mm|



Do Not Copy 

312/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.3** 

## **F0ManualSetting** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD02F|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Not set]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Non-CPU lens data – Maximum aperture” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

**==> picture [329 x 262] intentionally omitted <==**

**----- Start of picture text -----**<br>
Property Value  Description<br>0  Not set<br>120 F1.2<br>140  F1.4<br>180  F1.8<br>200  F2.0<br>250  F2.5<br>280 F2.8<br>330  F3.3<br>350  F3.5<br>400  F4.0<br>450  F4.5<br>500 F5.0<br>560  F5.6<br>630 F6.3<br>710  F7.1<br>800  F8.0<br>950  F9.5<br>1100  F11<br>1300 F13<br>1500  F15<br>1600  F16<br>1900  F19<br>2200  F22<br>**----- End of picture text -----**<br>


Do Not Copy 

313/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.4** 

## **SaveFocusPosition** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0CD|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the setting of “Save focus position” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



Do Not Copy 

314/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.5 ImageSensorCleaning** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD08F|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|2 [Clean at shutdown]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the setting of “Clean image sensor – Clean at startup/shutdown” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Cleaning off|
|2|Clean at shutdown|



Do Not Copy 

315/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.6 CommentString** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD090|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|NULL (0x00) 0 character|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates “Image comment” in the setup menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters (not including the null character). 

When the comment is not set in the camera, the length of the string is 0 (not including the null character). 

The camera does not send the DevicePropChanged event (subsection 6.4.1.6) even if the PropertyValue is changed. 

For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|



Do Not Copy 

316/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.7 EnableComment** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD091|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Not attached]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Image comment – Attach comment” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Not attached|
|1|Attached|



Do Not Copy 

317/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.8 ArtistV** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD072|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|NULL (0x00) 0 character|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates “Artist” in the setup menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 36 characters or shorter (not including the null character). 

If the artist is not set in the camera, the value is zero length string (not including the null character). 

For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made as shown below and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|A string exceeding 36 characters is set.|



## **6.5.5.9 CopyrightV** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD073|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|NULL (0x00) 0 character|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates “Copyright” in the setup menu. 

## ○ **Property Details** 

The PropertyValue is an optional string of 54 characters or shorter (not including the null character). 

If the copyright is not set in the camera, the value is zero length string (not including the null character). 

For the characters that can be input (ASCII code), refer to subsection 10.1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_DeviceProp_Format|Astring exceeding 54charactersis set.|



Do Not Copy 

318/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.10 EnableCopyright** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD053|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|Default Value|0 [Not attached]|
|Property Value|(Depends on the user setting)|



## ○ **Property Outline** 

Indicates “Copyright information– Attach copyright information” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Not attached|
|1|Attached|



Do Not Copy 

319/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.11 ExternalRecordingControl** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1DE|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “HDMI – Advanced – External recording control” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



Do Not Copy 

320/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.12 HDMIOutputDataDepth** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0CC|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [8 bits]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “HDMI – Advanced – Output data depth” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|8 bits|
|1|10 bits|



Do Not Copy 

321/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.13 MovieLogSetting** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0BF|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “HDMI – Advanced – N-log/HDR output options” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|N-Log|
|2|HDR (HLG)|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The HDMIOutputDataDepth property (subsection 6.5.5.12) is set to<br>[8 bits].|



Do Not Copy 

322/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.5.14 EnableShutter** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD08A|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|1 [Enable release]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Slot empty release lock” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Release locked|
|1|Enable release|



Do Not Copy 

323/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.6 Vendor (Power Supply)** 

## **6.5.6.1 ExternalDC-IN** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD101|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|DefaultValue|0 [Not connected]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the AC adapter connection status. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|Not connected|
|1|Connected|



Do Not Copy 

324/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7 Vendor (Camera Information)** 

## **6.5.7.1 UserMode** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0FC|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|DefaultValue|19 [P]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates [User mode] set in the camera. 

## ○ **Property Details** 

This property specifies the shooting mode when the ExposureProgramMode property (subsection 6.5.1.11) is set to [U1/U2/U3]. 

If the ExposureProgramMode property is set to [U1], this property specifies the shooting mode for U1.  If [U2] is set, this property specifies the shooting mode for U2.  If [U3] is set, this property specifies the shooting mode for U3. 

If any value other than [User mode] is set, the value of this property is not guaranteed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|19|P|
|20|S|
|21|A|
|22|M|
|23|AUTO|



Do Not Copy 

325/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.2 Orientation** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD10E|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Landscape or not fixed]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the orientation information. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Landscape or not fixed|
|1|Portrait (grip side upward)|
|2|Portrait (grip side downward)|
|3|Landscape (upside down)|



Do Not Copy 

326/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.3 RecordingMedia** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD10B|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Card]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the recording destination of the images captured by using the shutter-release button of the camera. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|Card|
|1|SDRAM|
|2|Card and SDRAM|



Do Not Copy 

327/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.4 ActiveSlot** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1F2|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Card not inserted]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the recording destination slot when the recording destination is a card. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Card not inserted|
|1|Slot 1|
|2|Slot 2|
|3|Slot1& slot2|



Do Not Copy 

328/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.5 ExposureRemaining** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1F1|
|DataType|UINT32|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [0 frames]|
|Property Value|0 [0 frames] to 4294967295 [4294967295 frames]|



## ○ **Property Outline** 

Indicates the number of frames that can be recorded on the card. 

## ○ **Property Details** 

The value changes depending on the setting of the camera.  When a card is not inserted in the camera, it should be 0 frames. 

Even if the total exceeds 4294967295 frames, the value of PropertyValue is set to 4294967295. 

Do Not Copy 

329/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.6 ContinuousShootingCount** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1B4|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get|
|Default Value|360 [360 frames]|
|Property Value|From 0 [0 frames] to 360 [360 frames]|



## ○ **Property Outline** 

Indicates the number of frames that can be recorded in continuous shooting by the command. The number of frames that can be recorded in continuous shooting can be acquired with any setting value of the RecordingMedia property (subsection 6.5.7.3). 

## ○ **Property Details** 

The number of continuous shooting frames changes depending on the following setting values on the camera. 

|Set contents|Property|
|---|---|
|Image quality mode|CompressionSetting property (subsection 6.5.1.3)|
|Image size|ImageSize property (subsection6.5.1.2)|
|Long exposure noise reduction|NoiseReduction property (subsection 6.5.2.53)|
|High ISO noise reduction|NoiseReductionHiIso property (subsection 6.5.2.54)|
|HDR|HDRMode property (subsection 6.5.2.64)|
|Max. continuous release|BurstMaxNumber property (subsection 6.5.4.13)|
|Chooseimage area|CaptureAreaCrop property (subsection6.5.2.3)|
|NEF (RAW) recording –<br>Compression Type|RawCompressionType property (subsection 6.5.2.5)|
|NEF (RAW) recording – NEF<br>(RAW) bit depth|RawCompressionBitMode property (subsection 6.5.2.6)|
|Silent shooting|SilentPhotography property (subsection 6.5.2.68)|
|Photo/Movie switching lever|LiveViewSelector property (subsection 6.5.12.8)|



Do Not Copy 

330/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.7 MovieRecFrameCount** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1B7|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|40 [40 frames]|
|Property Value|From 0 [0 frames] to 40 [40 frames]|



## ○ **Property Outline** 

Indicates the number of frames that can be recorded in photo shooting during recording movie. 

## ○ **Property Details** 

Number of frames become 0 when the MovieRecordScreenSize property (subsection 6.5.3.3) is set to [3840×2160 60p] or [3840×2160 50p] during movie live view. 

Do Not Copy 

331/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.8 AELockStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD105|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [Lock released]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the AE lock status. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Lock released|
|1|Locked|



Do Not Copy 

332/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.9 AFLockStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD104|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [Lock released]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the AF lock status. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Lock released|
|1|Locked|



Do Not Copy 

333/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.10 FVLockStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD106|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [Lock released]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the FV lock status. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Lock released|
|1|Locked|



Do Not Copy 

334/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.11 ShutterSpeed** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD100|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|(Minimum value in the setting range)|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Shutter speed” that is set in the camera. 

For the shutter speed during movie live view, the MovieShutterSpeed property (subsection 6.5.12.10) should be used. 

## ○ **Property Details** 

This property can handle the 1/1000 or low shutter speed in addition to the ExposureTime property (subsection 6.5.1.10). 

The enumerated values and the change factor are the same as that of the ExposureTime property except for the flash shooting synchronization speed. 

The flash shooting synchronization speed is set to 0xFFFFFFFE.  It is not the shutter speed specified in the flash shooting synchronization speed of the ExposureTime property. 

## ○ **Property Value** 

The valid PropertyValues are shown below.  (Excluding bulb shooting, flash shooting synchronization speed, and time shooting) 

|PropertyValue|Description|
|---|---|
|Upper 2 bytes|Numerator of the shutter speed|
|Lower 2bytes|Denominatorofthe shutterspeed|



(Example) Shutter speed 1/250 sec.  : PropertyValue = 0x000100FA (Example) Shutter speed 25 sec.  : PropertyValue = 0x00190001 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is not set to<br>[S] or [M].|
||The WarningStatus property (subsection 6.5.7.23) is [Sequence error]<br>or [Minimum aperture warning].|
||The TVLockSetting property (subsection 6.5.4.26) is set to [On].|
||The RetractableLensWarning property (subsection 6.5.10.9) is<br>[(Retractablelenswarning) On].|
||Bulb shooting or time shooting is set when the ExposureProgramMode<br>property (subsection 6.5.1.11) is [S].|
||Bulb shooting or time shooting is set when the HDRMode property<br>(subsection 6.5.2.64) is set to [On].|



Do Not Copy 

335/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.12 RemainingExposureTime** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0BE|
|DataType|UINT32|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 second|
|Property Value|From 0 to 900 second|



- **Property Outline** 

Indicates the remaining exposure time for photo shooting. 

## ○ **Property Details** 

The DevicePropChanged event is transmitted when the shooting mode is set to M and shooting is performed at the extended shutter speed. 

Do Not Copy 

336/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.13 FlexibleProgram** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD109|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get, Get / Set|
|Default Value|0 [0.0 EV]|
|Property Value|From-30 [-5 EV] to+30 [+5 EV]|



## ○ **Property Outline** 

Indicates the program shift value in units of 1/6 EV. 

## ○ **Property Details** 

When the value of the ExposureProgramMode property (subsection 6.5.1.11) is a value other than [P], the value of PropertyValue is not valid but set to 0. 

The StepSize of the property changes depending on the value of the ExposureEVStep property (subsection 6.5.4.6). 

|ExposureEVStep|StepSize|
|---|---|
|0 (1/3 EV)|2|
|1(1/2 EV)|3|
|2 (1 EV)|6|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than [P].|
||Displaying anerror/warning that prohibits programshift setting.|



Do Not Copy 

337/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.14 ISOControlSensitivity** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0B5|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|100 [ISO 100]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates ISO sensitivity that is controlled by the camera. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|Property Value|Description|
|---|---|---|---|
|50|Lo1.0|6400|ISO6400|
|56|Lo0.8|7200|ISO7200|
|64|Lo0.7|8000|ISO8000|
|72|Lo0.5|9000|ISO9000|
|80|Lo0.3|10000|ISO10000|
|90|Lo0.2|11000|ISO11000|
|100|ISO100|12800|ISO12800|
|110|ISO110|14400|ISO14400|
|125|ISO125|16000|ISO16000|
|140|ISO140|18000|ISO18000|
|160|ISO160|20000|ISO20000|
|180|ISO180|22000|ISO22000|
|200|ISO200|25600|ISO25600|
|220|ISO220|28800|ISO28800|
|250|ISO250|32000|ISO32000|
|280|ISO280|36000|ISO36000|
|320|ISO320|40000|ISO40000|
|360|ISO360|45600|ISO45600|
|400|ISO400|51200|ISO51200|
|450|ISO450|57600|Hi0.2|
|500|ISO500|64000|Hi0.3|
|560|ISO560|72000|Hi0.5|
|640|ISO640|81200|Hi0.7|
|720|ISO720|91200|Hi0.8|
|800|ISO800|102400|Hi1.0|
|900|ISO900|115000|Hi1.2|
|1000|ISO1000|128000|Hi1.3|
|1100|ISO1100|144000|Hi1.5|
|1250|ISO1250|162000|Hi1.7|
|1400|ISO1400|182000|Hi1.8|
|1600|ISO1600|204800|Hi2.0|
|1800|ISO1800|||
|2000|ISO2000|||
|2200|ISO2200|||
|2500|ISO2500|||
|2800|ISO2800|||
|3200|ISO3200|||
|3600|ISO3600|||
|4000|ISO4000|||
|4500|ISO4500|||
|5000|ISO5000|||
|5600|ISO5600|||



Do Not Copy 

338/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.15 StillCaptureModeSaveFrame** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1FF|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0x0001 [Single-frame shooting]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates “Release mode (saving frame)” setting on the camera. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0001|Single-frame shooting|
|0x0002|Continuous high-speed shooting|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The MovieReleaseButton property (subsection 6.5.4.28) is set to<br>[Movie shooting] during movie live view.|



Do Not Copy 

339/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.16 ExposureDisplayStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1B0|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [Normal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the display status of the shutter speed and the aperture value in the camera. 

## ○ **Property Details** 

   - It is 1 (only shutter speed is blinking) during bulb/time warning. 

- **Property Value** 

The valid PropertyValues are shown below. 

|||Shutterspeed|Shutterspeed|
|---|---|---|---|
|||Normal|Blinking|
|Aperture|Normal|0|1|
|value|Blinking|2|3|



Do Not Copy 

340/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.17 ExposureIndicateStatus** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1B1|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [0.0 EV]|
|Property Value|From-60 [-10 EV] to+60 [+10 EV]|



- **Property Outline** 

Indicates the display value of the indicator in units of 1/6 EV. 

When the ExposureIndicateLightup property (subsection 6.5.7.18) is [Off], the value of PropertyValue is not fixed. 

Do Not Copy 

341/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.18 ExposureIndicateLightup** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1B3|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [On]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the indicator display On/Off. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|On|
|1|Off|



Do Not Copy 

342/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.19 MonitorOffStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1BA|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Not monitor-off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the camera monitor off state. The actual monitor control status is not shown. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Not monitor-off|
|1|Monitor-off|



Do Not Copy 

343/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.20 AngleLevel** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD067|
|DataType|INT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0 [Horizontal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the level angle information of the camera. 

## ○ **Property Details** 

The valid angle information is shown below. 

From 0.0 degrees to 359.9999847412109375 degrees 

The angle information is 0.0 degrees when the camera is in the horizontal state.  The angle increases as the camera is rotated counterclockwise viewing from the person who operates the camera. 

When the camera is rotated clockwise starting from 0.0 degrees, the angle becomes 359.9999847412109375 degrees or smaller. 

When the camera is rotated counterclockwise starting from 359.9999847412109375 degrees, the angle becomes 0.0 degrees or larger. 

The angle information is displayed in green when it is horizontal or vertical in the virtual horizon of the setup menu. 

Add +0.5 degrees to the angle information and omit the value below the decimal section.  When the result is 0 or a multiple of 90 degrees, it is judged to be horizontal or vertical. 

Even if the PropertyValue is changed, the camera does not send a DevicePropChanged event (subsection 6.4.1.6). 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|Upper 16 bits|Integer section of the angle information|
|Lower 16 bits|Decimal section of the angle information|



*When the angle information cannot be acquired or it is not reliable, the PropertyValue is set to 0xFFFFFFFF. 

Do Not Copy 

344/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.21 AngleLevelPitching** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD07D|
|DataType|INT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0 [Horizontal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the level angle information (pitching) of the camera. 

## ○ **Property Details** 

The valid angle information is shown below. 

For the data type, the signed 32-bit fixed-point system is used, and the integer section and the decimal section use the upper 16 bits and the lower 16 bits, respectively. 

The angle information is 0.0 or 180.0 degrees when the camera is in the horizontal state.  The angle range is ±15 degrees from 0.0 or 180.0 degrees. 

|Camera<br>orientation|Lens<br>orientation|Angle range|Horizontal|
|---|---|---|---|
|Landscape|Up|From 0.0 to 60.0|0.0|
||Down|0.0, from 359.9999847412109375 to 300.0||
|Landscape<br>(upside down)|Up|From 180.0 to 120.0|180.0|
||Down|From 180.0 to 240.0||



The angle information is displayed in green when it is horizontal in the virtual horizon of the setup menu.  Add +0.5 degrees to the angle information and omit the value below the decimal section. When the result is 0.0 or 180.0 degrees, it is judged to be horizontal. 

Even if the PropertyValue is changed, the camera does not send a DevicePropChanged event (subsection 6.4.1.6). 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|Upper 16 bits|Integer section of the angle information|
|Lower 16 bits|Decimal section of the angle information|



*When the angle information cannot be acquired or it is not reliable, the PropertyValue is set to 0xFFFFFFFF. 

Do Not Copy 

345/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.22 AngleLevelYawing** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD07E|
|DataType|INT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0 [Horizontal]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the level angle information (yawing) of the camera. 

## ○ **Property Details** 

The valid angle information is shown below. 

For the data type, the signed 32-bit fixed-point system is used, and the integer section and the decimal section use the upper 16 bits and the lower 16 bits, respectively. 

The angle information is 0.0 or 180.0 degrees when the camera is in the horizontal state.  The angle range is ±15 degrees from 0.0 or 180.0 degrees. 

|Camera<br>orientation|Lens<br>orientation|Angle range|Horizontal|
|---|---|---|---|
|Portrait (grip side<br>upward)|Up|From 0.0 to 60.0|0.0|
||Down|0.0, from 359.9999847412109375 to 300.0||
|Portrait (grip side<br>downward)|Up|From 180.0 to 120.0|180.0|
||Down|From 180.0 to240.0||



The angle information is displayed in green when it is horizontal in the virtual horizon of the setup menu.  Add +0.5 degrees to the angle information and omit the value below the decimal section. When the result is 0.0 or 180.0 degrees, it is judged to be horizontal. 

Even if the PropertyValue is changed, the camera does not send a DevicePropChanged event (subsection 6.4.1.6). 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|Upper 16 bits|Integer section of the angle information|
|Lower 16 bits|Decimalsectionofthe angleinformation|



*When the angle information cannot be acquired or it is not reliable, the PropertyValue is set to 0xFFFFFFFF. 

Do Not Copy 

346/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.23 WarningStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD102|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0 [No warning]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the camera warning information. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

When the PropertyValue is set to any value other than 0, the release is locked. The PropertyValue takes the following values in the bit assignment.  (1: Valid, 0: Invalid) 

|Bit|Description|
|---|---|
|From Bit12toBit31|Reserved|
|Bit11|Version upgrade warning when mount<br>adapter is attached|
|Bit10|Retractablezoom-ringwarning|
|Bit9|Reserved|
|Bit8|Shooting error|
|Bit7|Reserved|
|Bit6|Bulb warning|
|Bit5|Minimumaperturewarning|
|Bit4|Reserved|
|Bit3|Reserved|
|Bit2|Reserved|
|Bit1|Battery exhausted|
|Bit0|Sequence error|



Do Not Copy 

347/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.24 InfoDisplayErrorStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1B2|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the error display status of the INFO display on the monitor. 

## ○ **Property Details** 

The error display conditions indicated by this property are as shown in the table below. 

|Name|Timing for starting message of errors and<br>warning|Finish timing|
|---|---|---|
|Release sequence error|After the release sequence is completed|Generation cause<br>released|
|Card access error|When the card is inserted or the card is<br>accessed|Generation cause<br>released|
|Battery ID unauthentication error|When a battery other than the exclusive ID<br>battery is mounted|Generation cause<br>released|
|Minimum aperture warning|When the Fmin detection switch is turned Off|Generation cause<br>released|
|Card write-protected & not-formatted<br>warning|When a card is inserted with the recording<br>destination set to “Card (Card and SDRAM)” or<br>when the recording destination is set to “Card<br>(Card and SDRAM)”while a card is inserted|Generation cause<br>released|
|Card not-formatted warning|Same as the above|Generation cause<br>released|
|Card write-protected warning|Same as the above|Generation cause<br>released|
|Battery exhausted (shutter release<br>disabled) warning|After the shutter-release button is pressed fully|Generation cause<br>released|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



Do Not Copy 

348/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.25 MovieRecProhibitionCondition** 

- **Property Specifications** 

|**roperty Specifications**||
|---|---|
|Property Code|0xD0A4|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x00000000|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the movie recording prohibition condition. 

## ○ **Property Details** 

When the PropertyValue is a value other than 0, the movie recording cannot be started. When the live view is not started, the value of PropertyValue is not fixed.  Even if a value has been entered, it is not guaranteed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

The PropertyValue takes the following values in the bit assignment.  (1: Valid, 0: Invalid) 

|Bit|Description|
|---|---|
|From Bit20 to Bit31|Reserved|
|Bit19|During warning / error of lens factor|
|Bit18|During sequence error|
|Bit17|The camera is running 10bits HDMI output and high load condition<br>(when all the following conditions are satisfied)<br>1. The camera is running HDMI output when the HDMIOutputDataDepth<br>property (subsection 6.5.5.12) is set to 10bits<br>2. The MovieRecordScreenSize property (subsection 6.5.3.3) is set to<br>[3840x2160], [1920x1080 120p], [1920x1080 100p] or [slow].<br>3. Acardisinserted.|
|Bit16|Reserved|
|Bit15|The MovieLogOutput property (subsection 6.5.7.27) is set to [On] and the<br>ExternalRecordingControl property (subsection 6.5.5.11) is set to [Off] or<br>during remote live view.|
|Bit14|The camera is not in the application mode.|
|Bit13|Duringliveviewphotography|
|Bit12|During enlarged display of live view|
|Bit11|Cardis protected.|
|Bit10|During movie recording|
|Bit9|There are images or movies not recorded in the buffer.|
|Bit8|Reserved|
|Bit7|Reserved|
|Bit6|Reserved|
|Bit5|Reserved|
|Bit4|Reserved|
|Bit3|No free area in the card|
|Bit2|Card not formatted|
|Bit1|Card access error|
|Bit0|No card inserted.|



Do Not Copy 

349/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.26 ActiveFolder** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD15B|
|DataType|UINT16|
|Description form|Range|
|Get / Set|Get|
|Default Value|100|
|Property Value|From 100 to 999|



## ○ **Property Outline** 

Indicates the folder number of the recording location. 

Do Not Copy 

350/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.7.27 MovieLogOutput** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0BB|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the state of N-log/HDR(HLG) control in the camera. 

Refer to the MovieLogSetting property (subsection 6.5.5.13) for output destination of control status. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off(Not outputting)|
|1|On (Outputting)|



Do Not Copy 

351/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.8 Vendor (Bracketing)** 

## **6.5.8.1 EnableBracketing** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0C0|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get / Set|
|DefaultValue|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the status of bracketing. 

## ○ **Property Details** 

PropertyValue becomes [Off] due to the combination of the setting of BracketingType property (subsection 6.5.2.63) and other settings. 

The conditions for canceling the bracketing are described below. 

|Conditions|Conditions|BracketingType property|BracketingType property||
|---|---|---|---|---|
|||AE Flash / AE / Flash|WB|ADL|
|Change BracketingType<br>property|WB`⇔`Changes between other<br>types|Cancel|Cancel|Cancel|
||ADL`⇔`Changes between other<br>types|Cancel|Cancel|Cancel|
|Change ExposureEVStep property (subsection 6.5.4.6)||Cancel|Not cancel|Not cancel|
|ChangeExposureCompEVStep property||Cancel|Not cancel|Not cancel|



During movie live view, bracketing shooting is not performed even if this property is set to [On]. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The HDRMode property (subsection 6.5.2.64) is [On].|
||The BracketingType property (subsection 6.5.2.63) is set to [WB<br>bracketing] and the CompressionSetting property (subsection 6.5.1.3)<br>is set to [RAW] or [RAW+JPEG].|
||The SilentPhotography property (subsection 6.5.2.68) is set to [On] and<br>the BracketingType property (subsection 6.5.2.63) is set to [Flash only].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|



Do Not Copy 

352/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.8.2 AEBracketingStep** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0C1|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|6 [1 EV]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the step range of AE bracketing. 

## ○ **Property Details** 

When the value of the ExposureEVStep property (subsection 6.5.4.6) is changed, the PropertyValue is set to 1 EV. 

When the BracketingType property (subsection 6.5.2.63) is set to [WB bracketing] or [ADL bracketing], the value of PropertyValue is not fixed. 

The value of PropertyValue changes depending on the value of the ExposureEVStep property (subsection 6.5.4.6). 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|ExposureEVStep|ExposureEVStep|ExposureEVStep|
|---|---|---|---|---|
|||1/3 EV|1/2 EV|1 EV|
|2|1/3EV|`✓`|-|-|
|3|1/2EV|-|`✓`|-|
|4|2/3EV|`✓`|-|-|
|6|1EV|`✓`|`✓`|`✓`|
|12|2EV|`✓`|`✓`|`✓`|
|18|3EV|`✓`|`✓`|`✓`|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The BracketingType property (subsection 6.5.2.63) is set to [WB<br>bracketing] or [ADL bracketing].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The HDRMode property (subsection 6.5.2.64) is [On].|
||The SilentPhotography property (subsection 6.5.2.68) is set to [On] and<br>theBracketingType property (subsection6.5.2.63)is set to [Flashonly].|



Do Not Copy 

353/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.8.3 AEBracketingPattern** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0C2|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x0403 [3 images (normal, under and over)]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the compensation direction and the number of images to be captured for AE bracketing. 

## ○ **Property Details** 

When the value of the ExposureEVStep property (subsection 6.5.4.6) is changed, the PropertyValue is set to [0 image]. 

When the BracketingType property (subsection 6.5.2.63) is set to [WB bracketing] or [ADL bracketing], the value of PropertyValue is not fixed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|0image|
|0x0102|2 images (normal and under)|
|0x0202|2 images (normal and over)|
|0x0103|3 images (normal and 2 unders)|
|0x0203|3 images (normal and 2 overs)|
|0x0403|3images (normal, underand over)|
|0x0405|5 images (normal, 2 unders and 2 overs)|
|0x0407|7 images (normal, 3 unders and 3 overs)|
|0x0409|9 images (normal, 4 unders and 4 overs)|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The BracketingType property (subsection 6.5.2.63) is set to [WB<br>bracketing] or [ADL bracketing].|
||When the AEBracketingStep property (subsection 6.5.8.2) is set to<br>[2EV] or [3EV], [7 images (normal, 3 unders and 3 overs)] or [9 images<br>(normal, 4 unders and 4 overs)] is set.|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything otherthan PSAM.|
||The HDRMode property (subsection 6.5.2.64) is [On].|
||The SilentPhotography property (subsection 6.5.2.68) is set to [On] and<br>theBracketingType property (subsection6.5.2.63)is set to [Flashonly].|



Do Not Copy 

354/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.8.4 AEBracketingCount** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0C3|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|1|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the number of the image (nth image) to be captured next for AE bracketing and ADL bracketing. 

## ○ **Property Details** 

When the EnableBracketing property (subsection 6.5.8.1) is set to [Off] and the BracketingType property (subsection 6.5.2.63) is set to [WB bracketing], the value of PropertyValue is not fixed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|From 1 to 9|AE bracketing|
|From 1to 5|ADLbracketing|



Do Not Copy 

355/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.8.5 WBBracketingStep** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0C4|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|1 [1 EV]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the step range for WB bracketing. 

## ○ **Property Details** 

When the BracketingType property (subsection 6.5.2.63) is set to anything other than [WB bracketing], the value of PropertyValue is not fixed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|1 EV|
|2|2 EV|
|3|3EV|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The BracketingType property (subsection 6.5.2.63) is set to anything<br>otherthan[WBbracketing].|
||The CompressionSetting property (subsection 6.5.1.3) is set to [RAW]<br>or [RAW+JPEG].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The HDRModeproperty (subsection 6.5.2.64)is[On].|



Do Not Copy 

356/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.8.6 WBBracketingPattern** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0C5|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x0403 [3 images (normal, under and over)]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the compensation direction and the number of images to be captured for WB bracketing. 

## ○ **Property Details** 

When the BracketingType property (subsection 6.5.2.63) is set to anything other than [WB bracketing], the value of PropertyValue is not fixed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|0image|
|0x0102|2 images (normal and under)|
|0x0202|2 images (normal and over)|
|0x0103|3 images (normal and 2 unders)|
|0x0203|3 images (normal and 2 overs)|
|0x0403|3images (normal, underand over)|
|0x0405|5 images (normal, 2 unders and 2 overs)|
|0x0407|7 images (normal, 3 unders and 3 overs)|
|0x0409|9 images (normal, 4 unders and 4 overs)|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The BracketingType property (subsection 6.5.2.63) is set to anything<br>other than [WB bracketing].|
||The CompressionSetting property (subsection 6.5.1.3) is set to [RAW]<br>or [RAW+JPEG].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The HDRModeproperty (subsection 6.5.2.64)is[On].|



Do Not Copy 

357/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.8.7 ADLBracketingPattern** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0C6|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0x0002 [2 shots (Off->User setting)]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the number of images to be captured for ADL bracketing. 

## ○ **Property Details** 

When the BracketingType property (subsection 6.5.2.63) is set to anything other than [ADL bracketing], the value of PropertyValue is not fixed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|0 shot|
|0x0002|2 shots (Off->User setting)|
|0x0003|3 shots (Off->Low->Normal)|
|0x0004|4 shots (Off->Low->Normal->High)|
|0x0005|5 shots (Off->Low->Normal->High->Extra high)|



- For the user setting, the setting value of the ADLBracketingStep property (subsection 6.5.8.8) should be used. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The BracketingType property (subsection 6.5.2.63) is set to anything<br>otherthan[ADLbracketing].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The HDRModeproperty (subsection 6.5.2.64)is[On].|



Do Not Copy 

358/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.8.8 ADLBracketingStep** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0C7|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0xFFFF [Auto]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the selected ADL with ADL bracketing set to two shots. 

## ○ **Property Details** 

When the BracketingType property (subsection 6.5.2.63) is set to anything other than [ADL bracketing], the value of PropertyValue is not fixed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0xFFFF|Auto|
|0x0002|Low|
|0x0003|Normal|
|0x0004|High|
|0x0005|Extra high|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The BracketingType property (subsection 6.5.2.63) is set to anything<br>other than [ADL bracketing].|
||The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||TheHDRMode property (subsection6.5.2.64)is [On].|



Do Not Copy 

359/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9 Vendor (External Flash)** 

## **6.5.9.1 ExternalSpeedLightExist** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD120|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|DefaultValue|0 [Notmounted]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the mounting status of the external flash. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|Not mounted|
|1|Mounted|



Do Not Copy 

360/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.2 ExternalSpeedLightSort** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD122|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Noncommunication]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the communication status of the external flash. 

## ○ **Property Details** 

When the ExternalSpeedLightExist property (subsection 6.5.9.1) is set to [Not mounted], the value of PropertyValue is not fixed. 

If the external flash for old-type communication is mounted, the PropertyValue becomes [Noncommunication]. 

For the communication status types of the external flash, refer to “External Flash Types” (subsection 11.6). 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Noncommunication|
|2|New-type communication (with the operating and setting section)|
|3|New-type communication(without the operating and setting section)|



Do Not Copy 

361/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.3 ExternalSpeedLightStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD121|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Not charged]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the charge status of the external flash. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Not charged|
|1|Ready|



*When the ExternalSpeedLightExist property (subsection 6.5.9.1) is set to [Not mounted], the value of PropertyValue is not fixed. 

Do Not Copy 

362/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.4 NewExternalSpeedLightMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD125|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the flash mode of the external flash (new-type communication). 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|i-TTL balanced fill flash|
|2|i-TTL fill flash|
|3|Auto aperture|
|4|Non-TTL auto|
|5|Distance-priority manual|
|6|Manual|
|7|Multi-flash|



- *When the ExternalSpeedLightExist property (subsection 6.5.9.1) is set to [Not mounted], the value of PropertyValue is not fixed. 

- *When the ExternalSpeedLightSort property (subsection 6.5.9.2) is set to anything other than [New-type communication], the value of PropertyValue is not fixed. 

Do Not Copy 

363/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.5 FlashCompensation** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD124|
|DataType|INT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [0.0 EV]|
|Property Value|From-18 [-3.0 EV] to+18 [+3.0 EV]|



## ○ **Property Outline** 

Indicates the flash compensation value in units of 1/6 EV. 

## ○ **Property Details** 

When the ExternalSpeedLightExist property (subsection 6.5.9.1) is set to [Not mounted], the value of PropertyValue is not fixed. 

When the ExternalSpeedLightSort property (subsection 6.5.9.2) is set to anything other than [New-type communication], the value of PropertyValue is not fixed. 

The value of PropertyValue is valid when the values of the ExternalSpeedLightSort property (subsection 6.5.9.2) and the NewExternalSpeedLightMode property (subsection 6.5.9.4) are as shown in the table below.  In the cases other than those in the table below, the value of PropertyValue is 0. 

|ExternalSpeedLightSort|NewExternalSpeedLightMode|
|---|---|
|Noncommunication|(Invalid)|
|New-type communication|i-TTL balanced fill flash<br>i-TTL fill flash<br>Auto aperture<br>Distance-priority manual|



Do Not Copy 

364/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.6 ExternalSpeedLightMultiFlashMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD12D|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Stand-alone flash]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the commander mode of the external flash. 

## ○ **Property Details** 

When the ExternalSpeedLightExist property (subsection 6.5.9.1) is set to [Not mounted], the value of PropertyValue is not fixed. 

When the ExternalSpeedLightSort property (subsection 6.5.9.2) is set to anything other than [New-type communication], the value of PropertyValue is not fixed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Stand-alone flash (Commander mode is invalid or not<br>supported)|
|1|Other flash units (Commander mode is valid)|



Do Not Copy 

365/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.7 SBWirelessMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1E2|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Stand-alone flash]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the wireless setting of the external flash. 

## ○ **Property Details** 

The supported property values change depending on the type of the flash attached to the camera or whether the wireless communication accessory is equipped or not.  If there’s no value supported, the property value is not fixed. 

If the supported property values change, it is informed by the DevicePropChanged event (subsection 6.4.1.6). 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Stand-alone flash|
|1|Other flashunits (Radio)|
|2|Other flash units (Optical)|
|3|Other flashunits (Optical + Radio)|



Do Not Copy 

366/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.8 SBWirelessMultipleFlashMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1E3|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Group flash units]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the flash mode of the external multiple flash. 

## ○ **Property Details** 

The supported property values change depending on the type of the flash attached to the camera or whether the wireless communication accessory is equipped or not.  If there’s no value supported, the property value is not fixed. 

When the SBWirelessMode property (subsection 6.5.9.7) is [Other flash units (Optical + Radio)], this property is fixed to [Group flash units]. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Group flash units|
|1|Quick wirelesslighting|
|2|Repeating|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>[Stand-alone flash].|



Do Not Copy 

367/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.9 SBUsableGroup** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1E4|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x00000000|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the available group of the external flash. 

## ○ **Property Details** 

The property value is the logical OR of the SBGroupIDs for available groups. If the property value is zero, any group cannot be used. For the details of SBGroupID, refer to subsection 7.6 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0x00000000|Cannot be used|
|Otherthan0x00000000|LogicalORofthe available SBGroupID|



Do Not Copy 

368/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.10 WirelessCLSEntryMode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1E5|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Pairing mode]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the setting of “Remote (WR) setting – Link mode” in the setup menu. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Pairing mode|
|1|PINcodemode|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The wireless remote controller is not installed.|
||The installed wireless remote controller doesn’t support the<br>radio-controlled AWL.|



Do Not Copy 

369/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.11 SBPINCode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1E6|
|DataType|UINT32|
|Description form|Range|
|Get / Set|Get, Get / Set|
|Default Value|0|
|Property Value|From 0 to 9999|



## ○ **Property Outline** 

Indicates the PIN code of “Remote (WR) setting – Link mode” in the setup menu. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The wireless remote controller is not installed.|
||The installed wireless remote controller doesn’t support the<br>radio-controlledAWL.|



Do Not Copy 

370/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.12 RadioMultipleFlashChannel** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1E7|
|DataType|UINT8|
|Description form|None|
|Get / Set|Get|
|Default Value|0|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the communication channel of the wireless remote controller. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|5|5CH|
|10|10CH|
|15|15CH|



Do Not Copy 

371/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.13 OpticalMultipleFlashChannel** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1E8|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|1 [CH]|
|Property Value|From 1 to 4 [CH]|



## ○ **Property Outline** 

Indicates the channel of the optical communication to the external flash. 

If the channel of the optical communication is not fixed, this property returns 0xFF as an invalid value. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>[Stand-alone flash] or [Other flash units (Radio)].|
||The flash supportingthe SB control is not attached.|



Do Not Copy 

372/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.14 FlashRangeDisplay** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1E9|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [meter]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the unit of distance for the setting of the external flash. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Meter|
|1|Feet|



Do Not Copy 

373/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.15 AllTestFiringDisable** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1EA|
|DataType|UINT8|
|Description form|None|
|Get / Set|Get|
|Default Value|0 [Enable firing]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the disabled state for the all test firing of the external flash. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Enable firing|
|Otherthan0|Disablefiring|



Do Not Copy 

374/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.16 SBSettingMemberLock** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1EC|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Unlock]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the lock state of the dials and the buttons on the external flash. 

## ○ **Property Details** 

The camera sets the default value when the external flash is disconnected from the camera or the session to the camera terminates. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Unlock|
|1|Lock|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExternalSpeedLightExist property (subsection 6.5.9.1) is set to<br>[Not mounted].|



Do Not Copy 

375/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.9.17 SBIntegrationFlashReady** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1ED|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Uncharged]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the information about the ready state of the external flash displayed in the flash info of the INFO display. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Uncharged|
|1|Ready|



Do Not Copy 

376/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.10 Vendor (Lens)** 

## **6.5.10.1 LensSort** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0E1|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|DefaultValue|1[CPUlensmounted]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the mounting status of the CPU lens. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0|Not mounted (lens not mounted or non-CPU lens mounted)|
|1|CPUlensmounted|



Do Not Copy 

377/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.10.2 LensTypeML** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0E7|
|DataType|UINT64|
|Description form|None|
|Get / Set|Get|
|Default Value|0|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

## Indicates information on the ML lens. 

The LensTypeF property (subsection 6.5.10.3) becomes effective only when the mount adapter of this property is valid. 

## ○ **Property Value** 

The valid PropertyValues are shown below. It is invalid when bit is 0, and valid when it is 1. 

|Bit|Description|
|---|---|
|From Bit8 toBit63|Reserved|
|Bit7|Lens whose automatic distortion correction is alwayseffective.|
|Bit6|Lens supporting automatic distortion correction|
|Bit5|DX lens (Lens for Nikon digital cameras)|
|Bit4|VR lens (with anti-vibration mechanism)|
|From Bit1toBit3|Reserved|
|Bit0|Mount adapter|



Do Not Copy 

378/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.10.3 LensTypeF** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0E2|
|DataType|UINT64|
|Description form|None|
|Get / Set|Get|
|Default Value|1 [D-type lens]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates information on the F-CPU lens. 

When the mount adapter is set to invalid in the LensTypeML property (subsection 6.5.10.2), the value of this property is fixed to zero. 

## ○ **Property Value** 

The valid PropertyValues are shown below. It is invalid when bit is 0, and valid when it is 1. 

|Bit|Description|
|---|---|
|From Bit9 toBit63|Reserved|
|Bit8|STM lens|
|Bit7|E-type lens (electromagnetic diaphragm)|
|Bit6|Retractable lens|
|Bit5|Lens supporting automatic distortion correction|
|Bit4|AF-Slens|
|Bit3|DX lens (Lens for Nikon digital cameras)|
|Bit2|VR lens (with anti-vibration mechanism)|
|Bit1|G-type lens (without aperture dial)|
|Bit0|D-type lens (with distance encoder)|



Do Not Copy 

379/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.10.4 LensID** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0E0|
|DataType|UINT16|
|Description form|None|
|Get / Set|Get|
|Default Value|0|
|Property Value|(Depends on the lens type)|



## ○ **Property Outline** 

Indicates the ID of the CPU lens. 

## ○ **Property Details** 

The value of PropertyValue indicates an ID (2Byte). 

When the value of the LensSort property (subsection 6.5.10.1) is set to [Not mounted], the value of PropertyValue is fixed to zero. 

Do Not Copy 

380/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.10.5 LensFocalMin** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0E3|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|5000 [50 mm]|
|Property Value|(Depends on the lens type)|



## ○ **Property Outline** 

Indicates the focal length at the Wide-end with the CPU lens mounted. 

## ○ **Property Details** 

The value of PropertyValue should be a hundred times the focal length (mm). 

When the value of the LensSort property (subsection 6.5.10.1) is set to [Not mounted], the value of PropertyValue is not fixed. 

## **6.5.10.6 LensFocalMax** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0E4|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|5000 [50 mm]|
|Property Value|(Depends on the lens type)|



## ○ **Property Outline** 

Indicates the focal length at the Tele-end with the CPU lens mounted. 

## ○ **Property Details** 

The value of PropertyValue should be a hundred times the focal length (mm). 

When the value of the LensSort property (subsection 6.5.10.1) is set to [Not mounted], the value of PropertyValue is not fixed. 

Do Not Copy 

381/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.10.7 LensApatureMin** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0E5|
|DataType|UINT16|
|Description form|None|
|Get / Set|Get|
|Default Value|140 [F 1.4]|
|Property Value|(Depends on the lens type)|



## ○ **Property Outline** 

Indicates the maximum aperture value at the Wide-end with the CPU lens mounted. 

## ○ **Property Details** 

The value of PropertyValue should be a hundred times the maximum aperture value. 

When the value of the LensSort property (subsection 6.5.10.1) is set to [Not mounted], the value of PropertyValue is not fixed. 

## **6.5.10.8 LensApatureMax** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD0E6|
|DataType|UINT16|
|Description form|None|
|Get / Set|Get|
|Default Value|1600 [F16]|
|Property Value|(Depends on the lens type)|



## ○ **Property Outline** 

Indicates the maximum aperture value at the Tele-end with the CPU lens mounted. 

## ○ **Property Details** 

The value of PropertyValue should be a hundred times the maximum aperture value. 

When the value of the LensSort property (subsection 6.5.10.1) is set to [Not mounted], the value of PropertyValue is not fixed. 

Do Not Copy 

382/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.10.9 RetractableLensWarning** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD09C|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|Default Value|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the retractable lens warning condition. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|(Retractable lens warning) Off|
|1|(Retractable lens warning) On|



Do Not Copy 

383/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.11 Vendor (USB)** 

## **6.5.11.1 USBSpeed** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD10C|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|DefaultValue|2[Super-Speed]|
|Property Value|Refer to Property Value in this subsection.|



- **Property Outline** 

Indicates the maximum data transfer speed of USB. 

When the Super-Speed is not selected, the property value is High-Speed. 

- **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|High-Speed|
|2|Super-Speed|



Do Not Copy 

384/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.11.2 ConnectionPath** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD12E|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [USB]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the connection path for PTP communication. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|USB|
|1|Wireless Transmitter|
|2|Built-in Wi-Fi|



Do Not Copy 

385/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12 Vendor (Live View)** 

## **6.5.12.1 CameraLiveViewStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1B8|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|DefaultValue|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the status of the live view in the camera. 

## ○ **Property Details** 

This property is set to “On” when live view is active. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



## **6.5.12.2 RemoteLiveViewStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1A2|
|DataType|UINT8|
|Description form|Range|
|Get / Set|Get|
|DefaultValue|0 [Off]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the status of the remote live view. 

## ○ **Property Details** 

This property is set to “On” when the StartLiveView command is executed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Off|
|1|On|



Do Not Copy 

386/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12.3 LiveViewImageStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1BB|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get|
|Default Value|0 [Live view image is not available]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the status of the live view image acquired by the GetLiveViewImageEx command. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Live view image is not available.|
|1|Live view image is available.|



Do Not Copy 

387/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12.4 LiveViewImageSize** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1AC|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|2 [Equivalent to VGA]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the size of the live view image acquired by the GetLiveViewImageEx command. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|Equivalent to QVGA (up to 320x240)|
|2|Equivalent to VGA (up to 640x480)|
|3|Equivalent to XGA (up to 1024x768)|



Do Not Copy 

388/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12.5 LiveViewImageCompression** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1BC|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Basic–Size priority]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the quality of the live view image acquired by the GetLiveViewImageEx command. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Basic–Size priority|
|1|Basic–Quality priority|
|2|Normal–Size priority|
|3|Normal –Quality priority|
|4|Fine–Size priority|
|5|Fine–Quality priority|



Do Not Copy 

389/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12.6 LiveViewZoomArea** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1BD|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|Default Value|0 [Entire display]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the zoom-area of the live view image. 

## ○ **Property Details** 

Available property value changes depending on the display device on the camera.  If you set a value that is not supported on the display device, it is changed to another area that has the same magnification. 

When switching the image monitor and the electronic viewfinder during zoom preview, the area before switching is maintained as the current value. 

In the following cases, the values that can be specified are limited, and the enumerated values vary. 

- A zoom value exceeds 100% in the spot WB acquisition standby state. 

- A zoom value other than 100% is set during movie recording. 

## ○ **Property Value** 

## The valid PropertyValues are shown below. 

|Property Value|Display device|Display device|Description|
|---|---|---|---|
||Image monitor|Electronic<br>viewfinder||
|0|`✓`|`✓`|Entire display|
|512|`✓`|-|Zoom area: 512x 342<br>Magnification: Zoom-in (200%)|
|640|-|`✓`|Zoom area: 640x 426<br>Magnification: Zoom-in(200%)|
|1024|`✓`|-|Zoom area: 1024x 682<br>Magnification:Equal(100%)|
|1280|-|`✓`|Zoom area: 1280x 854<br>Magnification:Equal(100%)|
|2048|`✓`|-|Zoom area: 2048x1364<br>Magnification: Zoom-out (50%)|
|2560|-|`✓`|Zoom area: 2560x1706<br>Magnification: Zoom-out (50%)|



The magnification is the magnification relative to the size of the display device. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Not_LiveView|The propertywas setina state otherthanduringliveview.|



Do Not Copy 

390/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12.7 LiveViewProhibitionCondition** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1A4|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x00000000|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the live view prohibition condition.  If there is any prohibition factor in this property, the StartLiveView command must not be issued.  If the StartLiveView command is issued and the live view is started when there is any prohibition factor in this property, the operation is not guaranteed. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

The PropertyValue takes the following values in the bit assignment.  (1: Valid, 0: Invalid) 

|Bit|Description|
|---|---|
|Bit31|Reserved|
|Bit30|Reserved|
|Bit29|Reserved|
|Bit28|Lens error<br>Versionupgradewarningwhen mount adapter is attached|
|Bit27|Reserved|
|Bit26|Reserved|
|Bit25|Reserved|
|Bit24|Reserved|
|Bit23|Reserved|
|Bit22|Reserved|
|Bit21|Reserved|
|Bit20|Reserved|
|Bit19|Reserved|
|Bit18|Reserved|
|Bit17|The live view cannot be started when the temperature rises.|
|Bit16|Reserved|
|Bit15|Processing by shooting<br>Until the shooting operation ends|
|Bit14|Reserved|
|Bit13|Reserved|
|Bit12|Reserved|
|Bit11|Reserved|
|Bit10|Reserved|
|Bit9|Reserved|
|Bit8|Battery exhausted|
|Bit7|Reserved|
|Bit6|Reserved|
|Bit5|Reserved|
|Bit4|Reserved|
|Bit3|Reserved|
|Bit2|Sequence error|
|Bit1|Reserved|
|Bit0|Reserved|



*When the PropertyValue is a value other than 0, the live view cannot be started. 

Do Not Copy 

391/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12.8 LiveViewSelector** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1A6|
|DataType|UINT8|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [Live view photography]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the state of live view mode. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0|Live view photography|
|1|Movie live view|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The camera is in the PC camera mode.|



Do Not Copy 

392/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12.9 MovieFnumber** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1A9|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|The minimum value of the enumeration|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the aperture value that is used for movie live view. 

## ○ **Property Details** 

When the LensSort property (subsection 6.5.10.1) is [Not mounted], the enumeration cannot be created.  Therefore, the number of enumeration values shall be 1 and the enumeration value, the DefaultValue, and the PropertyValue shall be the same value. 

For models that support the exposure meter interlocking lever, it changes depending on the F0ManualSetting property (subsection 6.5.5.3) and the state of the exposure meter interlocking lever.  The value shall be 1 EV except the maximum aperture value. 

It is set to 0 if the model does not support the exposure meter interlocking lever or if the aperture value cannot be acquired. 

If an aperture value error occurs, the number of enumeration values shall be 1 and the enumeration value, the DefaultValue, and the PropertyValue shall be 0xFFFF. 

If movie live view is not performed, the number of enumeration values shall be 1 and the enumeration value, the DefaultValue, and the PropertyValue shall be 0 because the value is not fixed. 

## ○ **Property Value** 

When the ExposureProgramMode property (subsection 6.5.1.11) is M or A, the PropertyValue is set to the value of the Fnumber property (subsection 6.5.1.5) just before the start of movie live view. When the ExposureProgramMode property (subsection 6.5.1.11) is other than M or A, the PropertyValue is set to a value depending on the camera. 

The PropertyValue should be a hundred times the aperture value. 

- The PropertyValue changes depending on the value of the ExposureEVStep property (subsection 

- 6.5.4.6). 

The setting range of PropertyValue changes depending on the lens and the magnification setting. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The value of the ExposureProgramMode property (subsection 6.5.1.11)<br>is not [A] or [M].|
||The value of the LensSort property (subsection 6.5.10.1) is [Not<br>mounted].|
||The WarningStatus property (subsection 6.5.7.23) is [Sequence error].|
||The RetractableLensWarning property (subsection 6.5.10.9) is<br>[(Retractablelenswarning) On].|
||An aperture value error.|
||Themovieliveview isnot executed.|



Do Not Copy 

393/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12.10 MovieShutterSpeed** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1A8|
|DataType|UINT32|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|The minimum value of the enumeration|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the shutter speed that is used for movie live view. 

## ○ **Property Details** 

The enumerated values change depending on the values of the ExposureEVStep property (subsection 6.5.4.6), the ExternalSpeedLightExist property (subsection 6.5.9.1), and the MovieRecordScreenSize property (subsection 6.5.3.3). 

The limit of the shutter speed that can be used in low speed changes depending on the setting of the movie frame rate. 

The relationship between each frame rate and the limit of the shutter speed that can be used in low speed is shown below. 

|Movieframerate|Shutterspeedlimitvalue|
|---|---|
|120fps|1/125|
|100fps|1/100|
|60fps|1/60|
|50fps|1/50|
|30fps|1/30|
|25fps|1/25|
|24fps|1/25|



If there is a change in the enumerated values, the enumerated values and the DefaultValue are updated. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|Upper 2bytes|Numeratorofthe shutterspeed|
|Lower 2 bytes|Denominator of the shutter speed|



*(Example) Shutter speed 1/250 sec.: PropertyValue = 0x000100FA 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The movie live view is not executed.|
||The value of the ExposureProgramMode property (subsection 6.5.1.11)<br>is anything other than M.|
||The WarningStatus property (subsection 6.5.7.23) is [Sequence error]<br>or [Minimum aperture warning].|
||The RetractableLensWarning property (subsection 6.5.10.9) is<br>[(Retractablelenswarning) On].|



Do Not Copy 

394/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.12.11 MovieExposureBiasCompensation** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD1AB|
|DataType|INT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|0 [0.0 EV]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the compensation value of the exposure compensation that is used for movie live view. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

The value of PropertyValue changes depending on the value of the ExposureEVStep property (subsection 6.5.4.6). 

||||ExposureEVStep||
|---|---|---|---|---|
|Property Value|Description|1/3 step|1/2 step|1 step|
|+3000|+3.0 EV|`✓`|`✓`|`✓`|
|+2666|+2.7 EV|`✓`|-|-|
|+2500|+2.5 EV|-|`✓`|-|
|+2333|+2.3 EV|`✓`|-|-|
|+2000|+2.0 EV|`✓`|`✓`|`✓`|
|+1666|+1.7 EV|`✓`|-|-|
|+1500|+1.5 EV|-|`✓`|-|
|+1333|+1.3 EV|`✓`|-|-|
|+1000|+1.0 EV|`✓`|`✓`|`✓`|
|+666|+0.7 EV|`✓`|-|-|
|+500|+0.5 EV|-|`✓`|-|
|+333|+0.3 EV|`✓`|-|-|
|0|0.0 EV|`✓`|`✓`|`✓`|
|-333|-0.3 EV|`✓`|-|-|
|-500|-0.5 EV|-|`✓`|-|
|-666|-0.7 EV|`✓`|-|-|
|-1000|-1.0 EV|`✓`|`✓`|`✓`|
|-1333|-1.3 EV|`✓`|-|-|
|-1500|-1.5 EV|-|`✓`|-|
|-1666|-1.7 EV|`✓`|-|-|
|-2000|-2.0 EV|`✓`|`✓`|`✓`|
|-2333|-2.3 EV|`✓`|-|-|
|-2500|-2.5 EV|-|`✓`|-|
|-2666|-2.7 EV|`✓`|-|-|
|-3000|-3.0 EV|`✓`|`✓`|`✓`|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>[Auto mode].|
||The movie live view is not executed.|



Do Not Copy 

395/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.13 Vendor (Picture Control)** 

## **6.5.13.1 ActivePicCtrlItem** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD200|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get / Set|
|DefaultValue|8 [Auto]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the picture control item whose setting is currently valid. 

## ○ **Property Value** 

## The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|Standard|
|2|Neutral|
|3|Vivid|
|4|Monochrome|
|5|Portrait|
|6|Landscape|
|7|Flat|
|8|Auto|
|101|Dream|
|102|Morning|
|103|Pop|
|104|Sunday|
|105|Somber|
|106|Drama|
|107|Silence|
|108|Bleach|
|109|Melancholic|
|110|Pure|
|111|Denim|
|112|Toy|
|113|Sepia|
|114|Blue|
|115|Red|
|116|Pink|
|117|Charcoal|
|118|Graphite|
|119|Binary|
|120|Carbon|
|From 201 to 209|Custom picture control (from 1 to 9)|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_Status|Setting to an unregistered area was performed for the custom picture<br>control.|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|



Do Not Copy 

396/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.13.2 MovieActivePicCtrlItem** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD237|
|DataType|UINT16|
|Description form|Enumeration|
|Get / Set|Get, Get / Set|
|Default Value|100 [Same as photo settings]|
|Property Value|Refer to Property Value in this subsection.|



## ○ **Property Outline** 

Indicates the picture control item whose setting is currently valid in the movie shooting menu. 

## ○ **Property Details** 

When the property value is set to [Same as photography setting], the picture control specified by ActivePicCtrlItem (6.5.13.1) is used. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|1|Standard|
|2|Neutral|
|3|Vivid|
|4|Monochrome|
|5|Portrait|
|6|Landscape|
|7|Flat|
|8|Auto|
|100|Same as photography setting|
|101|Dream|
|102|Morning|
|103|Pop|
|104|Sunday|
|105|Somber|
|106|Drama|
|107|Silence|
|108|Bleach|
|109|Melancholic|
|110|Pure|
|111|Denim|
|112|Toy|
|113|Sepia|
|114|Blue|
|115|Red|
|116|Pink|
|117|Charcoal|
|118|Graphite|
|119|Binary|
|120|Carbon|
|From 201to209|Custompicture control(from 1to 9)|



Do Not Copy 

397/484 

**Confidential** 

**Nikon Corporation** 

## **Confidential** 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Invalid_Status|Setting to an unregistered area was performed for the custom picture<br>control.|
|Access_Denied|The ExposureProgramMode property (subsection 6.5.1.11) is set to<br>anything other than PSAM.|
||The MovieLogOutput property (subsection 6.5.7.27) is [On].|



Do Not Copy 

398/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.5.14 Vendor (MTP)** 

## **6.5.14.1 SessionInitiatorVersionInfo** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD406|
|DataType|String|
|Description form|None|
|Get / Set|Get / Set|
|Default Value|“Windows/6.0.5330.0 MTPClassDriver/6.0.5330.0”<br>[Session initiator version information character string]|
|PropertyValue|(Depends onthe camera setting)|



## ○ **Property Outline** 

Indicates the version information of the host in open session. 

## ○ **Property Details** 

The PropertyValue should be a PTP string of 255 characters or shorter. (HTTP 1.1 spec (RFC 2068) User Agent string format) 

## **6.5.14.2 PerceivedDeviceType** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD407|
|DataType|UINT32|
|Description form|None|
|Get / Set|Get|
|Default Value|0x00000001 [Digital still camera]|
|PropertyValue|0x00000001[Digitalstillcamera]|



## ○ **Property Outline** 

Indicates the type of the device. 

## **6.5.14.3 UseDeviceStageFlag** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xD303|
|DataType|UINT8|
|Description form|None|
|Get / Set|Get|
|Default Value|0x01 [On]|
|PropertyValue|0x01[On]|



## ○ **Property Outline** 

Indicates that the device can use Device Stage when the PropertyValue is a value other than 0. Windows searches the metadata of Device Stage in the metadata service until the device installation is completed.  If the metadata of Device Stage in the server of Microsoft cannot be acquired, Windows displays Baseline Experience instead of Device Stage. 

Do Not Copy 

399/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6 ObjectPropCode** 

Each of the objects in the camera has various sorts of specific information.  As a method of transmission/reception of object information, an operation already exists in the PTP for operating the ObjectInfo data set.  However, this is a static data set that cannot be expanded and includes basic information on the object.  Various metadata concerning objects can be handled by operating the object property.  Each object property has a corresponding ObjectPropCode. 

The ObjectPropCodes supported by the camera are shown below. 

|Object Code|Description|Reference item|
|---|---|---|
|0xDC01|StorageID|6.6.1.1|
|0xDC02|ObjectFormat|6.6.1.2|
|0xDC03|ProtectionStatus|6.6.1.3|
|0xDC04|ObjectSize|6.6.1.4|
|0xDC07|ObjectFilename|6.6.1.5|
|0xDC08|DateCreated|6.6.1.6|
|0xDC09|DateModified|6.6.1.7|
|0xDC0B|ParentObject|6.6.1.8|
|0xDC0D|Hidden|6.6.1.9|
|0xDC41|PersistentUniqueObjectIdentifier|6.6.1.10|
|0xDC44|Name|6.6.1.11|
|0xDC81|RepresentativeSampleFormat|6.6.2.1|
|0xDC82|RepresentativeSampleSize|6.6.2.2|
|0xDC83|RepresentativeSampleHeight|6.6.2.3|
|0xDC84|RepresentativeSampleWidth|6.6.2.4|
|0xDC86|RepresentativeSampleData|6.6.2.5|
|0xDC87|Width|6.6.3.1|
|0xDC88|Height|6.6.3.2|
|0xDC8A|Rating|6.6.3.3|
|0xDCD3|ImageBitDepth|6.6.3.4|
|0xDC89|Duration|6.6.4.1|
|0xDE93|SampleRate|6.6.4.2|
|0xDE94|NumberOfChannels|6.6.4.3|
|0xDE97|ScanType|6.6.4.4|
|0xDE9A|AudioBitRate|6.6.4.5|
|0xDE9B|VideoFourCCCode|6.6.4.6|
|0xDE9C|VideoBitRate|6.6.4.7|



Do Not Copy 

400/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1 Object Information** 

## **6.6.1.1 StorageID** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC01|
|DataType|UINT32|
|Get / Set|Get|
|Default Value|0x00010001|
|Group Code|0x00000001|
|Form Flag|0x00 (None)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates the StorageID of the object.  (It is the same value as that of the first field of the ObjectInfo data set.) 

It is applied to the objects of all the formats supported by the camera. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x00010001|Slot 1|
|0x00020001|Slot2|



Do Not Copy 

401/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.2 ObjectFormat** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC02|
|DataType|UINT16|
|Get / Set|Get|
|DefaultValue|0x3000|
|Group Code|0x00000001|
|Form Flag|0x00 (None)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates the ObjectFormatCode of the object.  (It is the same value as that of the second field of the ObjectInfo data set.) 

It is applied to the objects of all the formats supported by the camera. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0x3000|Undefined|
|0x3001|Association|
|0x3002|Script|
|0x300D|MOV<br>Apple QuickTime Video Format（H.264/AVC）|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x380D|TIFF|
|0xB982|MP4 Container|



Do Not Copy 

402/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.3 ProtectionStatus** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC03|
|DataType|UINT16|
|Get / Set|Get|
|DefaultValue|0x0000|
|Group Code|0x00000001|
|Form Flag|0x02 (Enumeration)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates the protection status of the object.  (It is the same value as that of the third field of the ObjectInfo data set.) 

It is applied to the objects of all the formats supported by the camera. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Description|
|---|---|
|0x0000|Protection is not set.|
|0x0001|Protection is set.|



Do Not Copy 

403/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.4 ObjectSize** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC04|
|DataType|UINT64|
|Get / Set|Get|
|DefaultValue|0x0000000000000000|
|Group Code|0x00000001|
|Form Flag|0x00 (None)|
|PropertyValue|(Object size)|



## ○ **Property Outline** 

This indicates the size of the object in units of bytes.  (It is the same value as that of the fourth field of the ObjectInfo data set.) 

It is applied to the objects of all the formats supported by the camera. 

Do Not Copy 

404/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.5 ObjectFilename** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC07|
|DataType|String|
|Get / Set|Get|
|DefaultValue|0x00 (Null)|
|Group Code|0x00000001|
|Form Flag|0x05 (RegEx)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates an optional string that shows a file name of an object.  (It is the same value as that of the sixteenth field of the ObjectInfo data set.) 

It is applied to the objects of all the formats supported by the camera. 

However, the ObjectPropDesc returned in the Image format differs from that returned in the Association format. 

## ○ **Property Value** 

The valid PropertyValues are shown below. 

|ObjectFormat|RegEx|
|---|---|
|Association|[0-9]{3}[_a-zA-Z0-9]{5}|
|Otherthan Association|[_a-zA-Z]{4}[0-9]{4}¥.[a-zA-Z]{3}|



Do Not Copy 

405/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.6 DateCreated** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC08|
|DataType|String|
|Get / Set|Get|
|DefaultValue|0x00 (Null)|
|Group Code|0x00000001|
|Form Flag|0x03 (DateTime)|
|PropertyValue|(Date and time ofobject creation)|



## ○ **Property Outline** 

This indicates a string that shows the date and time of object creation.  (It is the same value as that of the seventeenth field of the ObjectInfo data set.) 

It is applied to the objects of all the formats supported by the camera. 

Do Not Copy 

406/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.7 DateModified** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC09|
|DataType|String|
|Get / Set|Get|
|DefaultValue|0x00 (Null)|
|Group Code|0x00000001|
|Form Flag|0x03 (DateTime)|
|PropertyValue|(Date and time ofobject update)|



## ○ **Property Outline** 

This indicates a string that shows the date and time of object update.  (It is the same value as that of the eighteenth field of the ObjectInfo data set.) It is applied to the objects of all the formats supported by the camera. 

Do Not Copy 

407/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.8 ParentObject** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC0B|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x00 (None)|
|PropertyValue|(ObjectHandle ofthe parent object ofthe specified object)|



## ○ **Property Outline** 

This indicates the ObjectHandle of the parent object of the object.  (It is the same value as that of the twelfth field of the ObjectInfo data set.) It is applied to the objects of all the formats supported by the camera. 

Do Not Copy 

408/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.9 Hidden** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC0D|
|DataType|UINT16|
|Get / Set|Get|
|DefaultValue|0x0000|
|Group Code|0x00000001|
|Form Flag|0x02 (Enumeration)|
|PropertyValue|(Hiddenattribute ofthe object)|



## ○ **Property Outline** 

This indicates a hidden attribute of the object. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3000|Undefined|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x300D|MOV<br>Apple QuickTime Video Format (H.264/AVC)|
|0x380D|TIFF|
|0xB982|MP4 Container|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Displayed object|
|0x0001|Hiddenobject|



Do Not Copy 

409/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.10 PersistentUniqueObjectIdentifier** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC41|
|DataType|UINT128|
|Get / Set|Get|
|DefaultValue|0x00^16|
|Group Code|0x00000001|
|Form Flag|0x00 (None)|
|PropertyValue|(Object-specificidentifier)|



## ○ **Property Outline** 

This indicates an object-specific identifier (PUOID). 

It is applied to the objects of all the formats supported by the camera. 

The generation rule of the PUOID is shown below. 

|0 through 3|4 through 15|
|---|---|
|ObjectHandle (4Byte)|Reserved (0)|



Do Not Copy 

410/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.1.11 Name** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC44|
|DataType|String|
|Get / Set|Get|
|DefaultValue|0x00 (Null)|
|Group Code|0x00000001|
|Form Flag|0x00 (None)|
|PropertyValue|(Filename ofanobject)|



## ○ **Property Outline** 

This indicates an optional string that shows a file name of an object.  (It should be the same value as that of ObjectFilename.) 

It is applied to the objects of all the formats supported by the camera. 

Do Not Copy 

411/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.2 Thumbnail** 

## **6.6.2.1 RepresentativeSampleFormat** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC81|
|DataType|UINT16|
|Get / Set|Get|
|Default Value|0x3000|
|Group Code|0x00000001|
|Form Flag|0x02 (Enumeration)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates the ObjectFormatCode of the thumbnail image. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x300D|MOV<br>Apple QuickTime Video Format (H.264/AVC)|
|0x380D|TIFF|
|0xB982|MP4 Container|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|PropertyValue|Setting|
|---|---|
|0x3000|Undefined|
|0x3808|JFIF|
|0x380D|TIFF|



Do Not Copy 

412/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.2.2 RepresentativeSampleSize** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC82|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x01 (Range)|
|PropertyValue|From0 to 0x00010000|



## ○ **Property Outline** 

This indicates the size of the thumbnail in bytes. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x300D|MOV<br>Apple QuickTimeVideoFormat (H.264/AVC)|
|0x380D|TIFF|
|0xB982|MP4Container|



Do Not Copy 

413/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.2.3 RepresentativeSampleHeight** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC83|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x01 (Range)|
|PropertyValue|From0 to120|



## ○ **Property Outline** 

This indicates the height of the thumbnail in pixels. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x300D|MOV<br>Apple QuickTimeVideoFormat (H.264/AVC)|
|0x380D|TIFF|
|0xB982|MP4Container|



Do Not Copy 

414/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.2.4 RepresentativeSampleWidth** 

## ○ **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC84|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x01 (Range)|
|PropertyValue|From0 to160|



## ○ **Property Outline** 

This indicates the width of the thumbnail in pixels. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x300D|MOV<br>Apple QuickTimeVideoFormat (H.264/AVC)|
|0x380D|TIFF|
|0xB982|MP4Container|



Do Not Copy 

415/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.2.5 RepresentativeSampleData** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC86|
|DataType|AUINT8|
|Get / Set|Get|
|DefaultValue|0x00000000|
|Group Code|0xFFFFFFFF|
|Form Flag|0x06 (ByteArray)|
|PropertyValue|From0 to 0x00010000|



## ○ **Property Outline** 

This indicates the thumbnail data. 

It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x300D|MOV<br>Apple QuickTimeVideoFormat (H.264/AVC)|
|0x380D|TIFF|
|0xB982|MP4Container|



Do Not Copy 

416/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.3 Image Information** 

## **6.6.3.1 Width** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC87|
|DataType|UINT32|
|Get / Set|Get|
|Default Value|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x01 (Range)|
|PropertyValue|From0 to10000|



## ○ **Property Outline** 

This indicates the width of the object in pixels. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x300D|MOV<br>Apple QuickTime Video Format (H.264/AVC)|
|0x380D|TIFF|
|0xB982|MP4 Container|



Do Not Copy 

417/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.3.2 Height** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC88|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x01 (Range)|
|PropertyValue|From0 to10000|



## ○ **Property Outline** 

This indicates the height of the object in pixels. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x300D|MOV<br>Apple QuickTimeVideoFormat (H.264/AVC)|
|0x380D|TIFF|
|0xB982|MP4Container|



Do Not Copy 

418/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.3.3 Rating** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC8A|
|DataType|UINT16|
|Get / Set|Get|
|DefaultValue|0x0000|
|Group Code|0x00000001|
|Form Flag|0x01 (Range)|
|PropertyValue|From0 to100|



## ○ **Property Outline** 

This indicates the rating of the object. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x300D|MOV<br>Apple QuickTimeVideoFormat (H.264/AVC)|
|0x380D|TIFF|
|0xB982|MP4Container|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Rating setting|
|---|---|
|0x0000|None|
|0x0001|`★`|
|0x0019|`★★`|
|0x0032|`★★★`|
|0x004B|`★★★★`|
|0x0063|`★★★★★`|



Do Not Copy 

419/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.3.4 ImageBitDepth** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDCD3|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x0000000C|
|Group Code|0x00000001|
|Form Flag|0x02 (Enumeration)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates the bit depth of the object. 

It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x3800|Unknown Image Object|
|0x3801|EXIF/JPEG|
|0x380D|TIFF|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000000C|12bit|
|0x0000000E|14bit|
|0x00000018|24bit|



Do Not Copy 

420/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.4 Movie Information** 

## **6.6.4.1 Duration** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDC89|
|DataType|UINT32|
|Get / Set|Get|
|Default Value|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x01 (Range)|
|PropertyValue|From0 to 0x001B773F(1799999msec)|



- **Property Outline** 

This indicates the length of the object in msec. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x300D|MOV<br>Apple QuickTimeVideoFormat (H.264/AVC)|
|0xB982|MP4 Container|



Do Not Copy 

421/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.4.2 SampleRate** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDE93|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x02 (Enumeration)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates the sample rate of the object. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x300D|MOV<br>Apple QuickTime Video Format (H.264/AVC)|
|0xB982|MP4 Container|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x00000000|0Hz(no sound)/Unknown|
|0x00002EE0|12.000 Hz|
|0x00005DC0|24.000 Hz|
|0x0000BB80|48.000 Hz|



Do Not Copy 

422/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.4.3 NumberOfChannels** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDE94|
|DataType|UINT16|
|Get / Set|Get|
|DefaultValue|0x0000|
|Group Code|0x00000001|
|Form Flag|0x02 (Enumeration)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates the number of channels of the object. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x300D|MOV<br>Apple QuickTime Video Format (H.264/AVC)|
|0xB982|MP4 Container|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Unused (no sound)/Unknown|
|0x0001|Monaural (1ch)|
|0x0002|Stereo (2ch)|



Do Not Copy 

423/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.4.4 ScanType** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDE97|
|DataType|UINT16|
|Get / Set|Get|
|DefaultValue|0x0000|
|Group Code|0x00000001|
|Form Flag|0x02 (Enumeration)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates the scan type of the object. 

It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x300D|MOV<br>Apple QuickTime Video Format (H.264/AVC)|
|0xB982|MP4 Container|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x0000|Unused|



Do Not Copy 

424/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.4.5 AudioBitRate** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDE9A|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x01 (Range)|
|PropertyValue|From0x00000000 (No sound/Unknown) to 0x00177000|



## ○ **Property Outline** 

This indicates the audio bit rate of the object. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x300D|MOV<br>Apple QuickTime Video Format (H.264/AVC)|
|0xB982|MP4 Container|



Do Not Copy 

425/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.4.6 VideoFourCCCode** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDE9B|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x31637661|
|Group Code|0x00000001|
|Form Flag|0x02 (Enumeration)|
|PropertyValue|RefertoPropertyValueinthis subsection.|



## ○ **Property Outline** 

This indicates the FourCC code for the video codec. It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x300D|MOV<br>Apple QuickTime Video Format (H.264/AVC)|
|0xB982|MP4 Container|



## ○ **Property Value** 

The valid PropertyValues are shown below. 

|Property Value|Description|
|---|---|
|0x31637661|“avc1”|



Do Not Copy 

426/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.6.4.7 VideoBitRate** 

- **Property Specifications** 

|**Property Specifications**||
|---|---|
|Property Code|0xDE9C|
|DataType|UINT32|
|Get / Set|Get|
|DefaultValue|0x00000000|
|Group Code|0x00000001|
|Form Flag|0x01 (Range)|
|PropertyValue|From0x00000000 (Unknown) to 0x30000000|



## ○ **Property Outline** 

This indicates the number of bits of the object processed per sec. 

The PropertyValue should be a value obtained by multiplying the maximum number of bytes per sec. of the object by 8 (bit). 

It is applied to the objects of the following formats. 

|ObjectFormatCode|Description|
|---|---|
|0x300D|MOV<br>Apple QuickTime Video Format (H.264/AVC)|
|0xB982|MP4Container|



Do Not Copy 

427/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7 SBAttributeCode** 

The flash has various peculiar information.  The various metadata for the flash can be handled by operating the flash attributes.  Each flash attribute has corresponding SBAttrID and SBGroupAttrID. 

|The camera supports<br>SBAttrID<br>0x1001<br>0x1002<br>0x1003<br>0x1005<br>SBGroupAttrID<br>0x4001<br>0x4002<br>0x4003<br>0x4004<br>0x4005<br>0x4006<br>0x4007<br>0x4008<br>0x4009|The camera supports<br>SBAttrID<br>0x1001<br>0x1002<br>0x1003<br>0x1005<br>SBGroupAttrID<br>0x4001<br>0x4002<br>0x4003<br>0x4004<br>0x4005<br>0x4006<br>0x4007<br>0x4008<br>0x4009|the following SBAttrID and SBGroupAttrID.|the following SBAttrID and SBGroupAttrID.|
|---|---|---|---|
||SBAttrID|Description|Reference|
||0x1001|SBName|6.7.1.1|
||0x1002|SBGroupID|6.7.1.2|
||0x1003|SBStatus|6.7.1.3|
||0x1005|SBTestFlashDisable|6.7.1.4|
|||||
||SBGroupAttrID|Description|Reference|
||0x4001|SBGroupFlashMode|6.7.2.1|
||0x4002|SBGroupFlashCompensation|6.7.2.2|
||0x4003|SBGroupFlashRatio|6.7.2.3|
||0x4004|SBGroupFlashLevel|6.7.2.4|
||0x4005|SBGroupFlashRange|6.7.2.5|
||0x4006|SBGroupRepeat|6.7.2.6|
||0x4007|SBGroupRepeatCount|6.7.2.7|
||0x4008|SBGroupRepeatInterval|6.7.2.8|
||0x4009|SBGroupValid|6.7.2.9|



Do Not Copy 

428/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.1 SBAttribute** 

## **6.7.1.1 SBName** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBAttrID|0x1001|
|DataType|String|
|Get / Set|Get / Set|
|Default Value|“Noused”|
|FormFlag|None|
|Attribute Value|(SB model name / nickname)|



## ○ **Attribute Outline** 

This indicates the string to express the name or the nickname of the remote flash. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The movie live view is being performed.|



## **6.7.1.2 SBGroupID** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBAttrID|0x1002|
|DataType|SBGroupID|
|Get / Set|Get|
|Default Value|0x00000000|
|FormFlag|Enumeration|
|Attribute Value|Refer to Attribute Value in this subsection.|



## ○ **Attribute Outline** 

This indicates the SBGroupID of the flash. 

## ○ **Attribute Value** 

For the AttributeValue, refer to the SBGroupID (subsection 7.6). 

Do Not Copy 

429/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.1.3 SBStatus** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBAttrID|0x1003|
|DataType|UINT8|
|Get / Set|Get|
|DefaultValue|0x01|
|FormFlag|None|
|Attribute Value|Refer to Attribute Value in this subsection.|



## ○ **Attribute Outline** 

This indicates the ready state of the remote flash. 

## ○ **Attribute Details** 

When getting this attribute with specifying the master flash, the GetSBAttrDesc and the GetSBAttrValue commands respond Invalid_Parameter. 

Use the ExternalSpeedLightStatus property (subsection 6.5.9.3) to get the ready state of the master flash. 

## ○ **Attribute Value** 

The valid AttributeValues are shown below. 

|AttributeValue|Description|
|---|---|
|From Bit3 to Bit7|(Reserved)|
|Bit2|High temperature error|
|Bit1|Batterywarning|
|Bit0|Ready|



## **6.7.1.4 SBTestFlashDisable** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBAttrID|0x1005|
|DataType|UINT8|
|Get / Set|Get|
|DefaultValue|0|
|FormFlag|None|
|AttributeValue|RefertoAttributeValueinthis subsection.|



## ○ **Attribute Outline** 

This indicates the disabled state for the test firing of the flash. 

## ○ **Attribute Value** 

The valid AttributeValues are shown below. 

|Attribute Value|Description|
|---|---|
|0|Enable firing|
|Other than 0|Disable firing|



Do Not Copy 

430/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.2 SBGroupAttribute** 

## **6.7.2.1 SBGroupFlashMode** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBGroupAttrID|0x4001|
|DataType|UINT8|
|Get / Set|Get / Set|
|Default Value|The default value differs depending on the flash group.|
|FormFlag|Enumeration|
|Attribute Value|Refer to Attribute Value in this subsection.|



## ○ **Attribute Outline** 

This indicates the flash mode of the flash group. 

## ○ **Attribute Value** 

The valid AttributeValues are shown below. 

|AttributeValue|Description|
|---|---|
|0|Off|
|1|[TTL-BL] i-TTL balanced fill flash*|
|2|[TTL] i-TTL fill flash|
|3|[AA] Auto aperture|
|4|[A]Non-TTLauto*|
|5|[GN] Distance-priority manual*|
|6|[M]Manual|
|7|[RPT] Repeating flash*|



- This can be used on the case of the stand-alone flash or the main flash. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The flash group that cannot be used was specified.<br>(The specified group is not in the values of the SBUsableGroup<br>(subsection 6.5.9.9).)|
||The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>anything other than [Stand-alone flash] and the value of the<br>SBWirelessMultipleFlashMode property (subsection 6.5.9.8) is<br>[Repeating].|



* Except that the value of the SBWirelessMode property (subsection 6.5.9.7) is anything other than [Stand-alone flash] and the value of the SBWirelessMultipleFlashMode property (subsection 6.5.9.8) is [Quick wireless lighting]. 

Do Not Copy 

431/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.2.2 SBGroupFlashCompensation** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBGroupAttrID|0x4002|
|DataType|INT8|
|Get / Set|Get, Get / Set|
|DefaultValue|0 [0.0EV]|
|FormFlag|Range|
|Attribute Value|From-18[-3.0EV] to+18[+3.0EV]|



## ○ **Attribute Outline** 

This indicates the flash group compensation value in units of 1/6 EV. 

When the attached flash does not support this function, the value of this attribute is not fixed. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The flash group that cannot be used was specified.<br>(The specified group is not in the values of the SBUsableGroup<br>(subsection 6.5.9.9).)|
||The value of the SBGroupFlashMode property (subsection 6.7.2.1) for<br>the specifiedflashgroupis [Off], [Manual] or[Repeatingflash].|
||The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>anything other than [Stand-alone flash] and the value of the<br>SBWirelessMultipleFlashMode property (subsection 6.5.9.8) is<br>[Repeating].|



* Except that the value of the SBWirelessMode property (subsection 6.5.9.7) is anything other than [Stand-alone flash] and the value of the SBWirelessMultipleFlashMode property (subsection 6.5.9.8) is [Quick wireless lighting]. 

Do Not Copy 

432/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.2.3 SBGroupFlashRatio** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBGroupAttrID|0x4003|
|DataType|UINT8|
|Get / Set|Get, Get / Set|
|DefaultValue|7[1:1]|
|FormFlag|Enumeration|
|Attribute Value|Refer to Attribute Value in this subsection.|



## ○ **Attribute Outline** 

This indicates the ratio of the flash group. 

## ○ **Attribute Value** 

The valid AttributeValues are shown below. 

When the attached flash does not support this function, the value of this attribute is not fixed. 

**==> picture [329 x 175] intentionally omitted <==**

**----- Start of picture text -----**<br>
Attribute Value Description<br>0  1:--<br>1  8:1<br>2  6:1<br>3  4:1<br>4  3:1<br>5  2:1<br>6  1.5:1<br>7  1:1<br>8  1:1.5<br>9 1:2<br>10  1:3<br>11  1:4<br>12  1:6<br>13  1:8<br>14  --:1<br>**----- End of picture text -----**<br>


## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>[Stand-alone flash].|
||The value of the SBWirelessMultipleFlashMode property (subsection<br>6.5.9.8)is otherthan[Quick wirelesslighting].|



Do Not Copy 

433/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.2.4 SBGroupFlashLevel** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBGroupAttrID|0x4004|
|DataType|UINT8|
|Get / Set|Get, Get / Set|
|DefaultValue|The defaultvalue differs depending ontheflash mode.|
|FormFlag|Enumeration|
|Attribute Value|Refer to Attribute Value in this subsection.|



## ○ **Attribute Outline** 

This indicates the flash level of the flash group. 

## ○ **Attribute Value** 

The valid AttributeValues are shown below. 

**==> picture [329 x 283] intentionally omitted <==**

**----- Start of picture text -----**<br>
Attribute Value  Description<br>1  1/1(Full)<br>2  1/1 – 0.3(Full - 1/3 step)<br>3  1/1 – 0.7(Full - 2/3 step)<br>4  1/2<br>5  1/2 – 0.3<br>6  1/2 – 0.7<br>7  1/4<br>8  1/4 – 0.3<br>9 1/4 – 0.7<br>10  1/8<br>11  1/8 – 0.3<br>12  1/8 – 0.7<br>13  1/16<br>14  1/16 – 0.3<br>15  1/16 – 0.7<br>16  1/32<br>17  1/32 – 0.3<br>18  1/32 – 0.7<br>19 1/64<br>20  1/64 – 0.3<br>21  1/64 – 0.7<br>22  1/128<br>23  1/128 – 0.3<br>24  1/128 – 0.7<br>25  1/256<br>**----- End of picture text -----**<br>


## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The flash group that cannot be used was specified.<br>(The specified group is not in the values of the SBUsableGroup<br>(subsection6.5.9.9).)|
||The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>[Stand-alone flash] and the value of the SBGroupFlashMode property<br>(subsection 6.7.2.1) for the master flash is not [Off], [Manual] or<br>[Repeatingflash].|
||The value of the SBGroupFlashMode property (subsection 6.7.2.1) is<br>otherthan[Manual].|



* Except that the value of the SBWirelessMode property (subsection 6.5.9.7) is anything other than [Stand-alone flash] and the value of the SBWirelessMultipleFlashMode property (subsection 6.5.9.8) is [Quick wireless lighting] or [Repeating]. 

Do Not Copy 

434/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.2.5 SBGroupFlashRange** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBGroupAttrID|0x4005|
|DataType|UINT32|
|Get / Set|Get, Get / Set|
|DefaultValue|13 [2.0[m]/6.6[ft]]|
|FormFlag|Enumeration|
|Attribute Value|Refer to Attribute Value in this subsection.|



## ○ **Attribute Outline** 

This indicates the distance of the flash group. 

## ○ **Attribute Value** 

The valid AttributeValues are shown below. 

When the attached flash does not support this function, the value of this attribute is not fixed. 

|AttributeValue|Description|AttributeValue|Description|
|---|---|---|---|
|0|0.3[m]/1.0[ft]|17|3.2[m]/10[ft]|
|1|0.4[m]/1.3[ft]|18|3.6[m]/12[ft]|
|2|0.5[m]/1.7[ft]|19|4.0[m]/13[ft]|
|3|0.6[m]/2.0[ft]|20|4.5[m]/15[ft]|
|4|0.7[m]/2.3[ft]|21|5.0[m]/17[ft]|
|5|0.8[m]/2.6[ft]|22|5.6[m]/19[ft]|
|6|0.9[m]/2.9[ft]|23|6.3[m]/21[ft]|
|7|1.0[m]/3.3[ft]|24|7.1[m]/23[ft]|
|8|1.1[m]/3.7[ft]|25|8.0[m]/26[ft]|
|9|1.3[m]/4.1[ft]|26|9.0[m]/29[ft]|
|10|1.4[m]/4.6[ft]|27|10[m]/33[ft]|
|11|1.6[m]/5.2[ft]|28|11[m]/37[ft]|
|12|1.8[m]/5.8[ft]|29|13[m]/42[ft]|
|13|2.0[m]/6.6[ft]|30|14[m]/47[ft]|
|14|2.2[m]/7.4[ft]|31|16[m]/52[ft]|
|15|2.5[m]/8.3[ft]|32|18[m]/59[ft]|
|16|2.8[m]/9.3[ft]|33|20[m]/66[ft]|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The group of the master flash is invalid in the SBUsableGroup property<br>(subsection6.5.9.9).|
||The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>other than [Stand-alone flash].|
||The value of the SBGroupFlashMode property (subsection 6.7.2.1) for<br>the master flash is other than [Distance-priority manual].|



Do Not Copy 

435/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.2.6 SBGroupRepeat** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBGroupAttrID|0x4006|
|DataType|UINT8|
|Get / Set|Get, Get / Set|
|DefaultValue|The defaultvalue differs depending ontheflashgroup.|
|FormFlag|Enumeration|
|Attribute Value|Refer to Attribute Value in this subsection.|



## ○ **Attribute Outline** 

This indicates the repeat setting of the flash group. 

## ○ **Attribute Value** 

The valid AttributeValues are shown below. 

When the attached flash does not support this function, the value of this attribute is not fixed. 

|AttributeValue|Description|
|---|---|
|0|Off|
|1|On|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The flash group that cannot be used was specified.<br>(The specified group is not in the values of the SBUsableGroup<br>(subsection 6.5.9.9).)|
||The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>anything other than [Stand-alone flash] and the value of the<br>SBWirelessMultipleFlashMode property (subsection 6.5.9.8) is not<br>[Repeating].|
||The value of the SBUsableGroup property (subsection 6.5.9.9) is zero<br>(Cannot be used).|



Do Not Copy 

436/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.2.7 SBGroupRepeatCount** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBGroupAttrID|0x4007|
|DataType|UINT8|
|Get / Set|Get, Get / Set|
|DefaultValue|10|
|FormFlag|Range|
|Attribute Value|From 2 to 90|



## ○ **Attribute Outline** 

This indicates the firing count of the flash group. 

When the attached flash does not support this function, the value of this attribute is not fixed. 

## ○ **Attribute Details** 

The upper limit of the attribute value varies depending on the setting of the flash level and frequency.  If the upper limit value varies, it is informed by the SBGroupAttrChanged event (subsection 6.4.2.13). 

The number from 2 to 10 and the even number over 10 can be set. When the odd number from 10 to 90 was set, it is converted to the even number by adding 1. 

## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>[Stand-alone flash] and the group of the master flash is invalid in the<br>SBUsableGroup property (subsection 6.5.9.9).|
||The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>anything other than [Stand-alone flash] and the value of the<br>SBWirelessMultipleFlashMode property (subsection 6.5.9.8) is not<br>[Repeating].|
||The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>[Stand-alone flash] and the value of the SBGroupFlashMode property<br>(subsection 6.7.2.1) for the master flash is not [Repeating flash].|
||The value of the SBUsableGroup property (subsection 6.5.9.9) is zero<br>(Cannot be used).|



Do Not Copy 

437/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.2.8 SBGroupRepeatInterval** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBGroupAttrID|0x4008|
|DataType|UINT16|
|Get / Set|Get, Get / Set|
|DefaultValue|9[10Hz]|
|FormFlag|Enumeration|
|Attribute Value|Refer to Attribute Value in this subsection.|



## ○ **Attribute Outline** 

This indicates the repeat interval of the flash group. 

## ○ **Attribute Value** 

The valid AttributeValues are shown below. 

When the attached flash does not support this function, the value of this attribute is not fixed. 

|AttributeValue|Description|
|---|---|
|0|1Hz|
|1|2Hz|
|2|3Hz|
|3|4Hz|
|4|5Hz|
|5|6Hz|
|6|7Hz|
|7|8Hz|
|8|9Hz|
|9|10Hz|
|10|20Hz|
|11|30Hz|
|12|40Hz|
|13|50Hz|
|14|60Hz|
|15|70Hz|
|16|80Hz|
|17|90Hz|
|18|100Hz|



## ○ **Response Code** 

When the value is set under the following conditions, an error response is made and the value cannot be set. 

|Response Code|Description|
|---|---|
|Access_Denied|The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>[Stand-alone flash] and the group of the master flash is invalid in the<br>SBUsableGroup property (subsection 6.5.9.9).|
||The value of the SBWirelessMode property (subsection 6.5.9.7) is anything<br>other than [Stand-alone flash] and the value of the<br>SBWirelessMultipleFlashMode property (subsection 6.5.9.8) is not<br>[Repeating].|
||The value of the SBWirelessMode property (subsection 6.5.9.7) is<br>[Stand-alone flash] and the value of the SBGroupFlashMode property<br>(subsection 6.7.2.1) for the master flash is not [Repeating flash].|
||The value of the SBUsableGroup property (subsection 6.5.9.9) is zero<br>(Cannot be used).|



Do Not Copy 

438/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **6.7.2.9 SBGroupValid** 

- **Attribute Specifications** 

|**Attribute Specifications**||
|---|---|
|SBGroupAttrID|0x4009|
|DataType|UINT8|
|Get / Set|Get|
|DefaultValue|0|
|FormFlag|None|
|Attribute Value|Refer to Attribute Value in this subsection.|



## ○ **Attribute Outline** 

This indicates the valid state of the flash group. 

## ○ **Attribute Value** 

The valid AttributeValues are shown below. 

|AttributeValue|Description|
|---|---|
|0|Invalid group|
|Other than 0|Valid group|



Do Not Copy 

439/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **7 Data Type** 

## **7.1 DataTypeCode** 

The standard data types used by the camera are shown below. 

|DataTypeCode|Type|Description|
|---|---|---|
|0x0001|INT8|Signed 8-bit integer|
|0x0002|UINT8|Unsigned 8-bit integer|
|0x0003|INT16|Signed 16-bit integer|
|0x0004|UINT16|Unsigned16-bitinteger|
|0x0005|INT32|Signed 32-bit integer|
|0x0006|UINT32|Unsigned 32-bitinteger|
|0x0007|INT64|Signed 64-bit integer|
|0x0008|UINT64|Unsigned 64-bit integer|
|0x0009|INT128|Signed 128-bit integer|
|0x000A|UINT128|Unsigned 128-bit integer|
|0x4001|AINT8|Signed 8-bitintegerarray|
|0x4002|AUINT8|Unsigned 8-bit integer array|
|0x4003|AINT16|Signed 16-bit integer array|
|0x4004|AUINT16|Unsigned 16-bit integer array|
|0x4005|AINT32|Signed 32-bit integer array|
|0x4006|AUINT32|Unsigned 32-bitintegerarray|
|0x4007|AINT64|Signed 64-bit integer array|
|0x4008|AUINT64|Unsigned 64-bit integer array|
|0x4009|AINT128|Signed 128-bit integer array|
|0x400A|AUINT128|Unsigned 128-bit integer array|
|0xFFFF|STR|VariablelengthUnicode characterstring|



Do Not Copy 

440/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **7.2 Character String Format** 

The field representing the character string complies with the following format. Each field data is stored in the little endian format. 

|Field|Size (Byte)|Data|Description|
|---|---|---|---|
|NumChar|1|N|Represents the number of<br>characters in the string.<br>The terminating null character is<br>included.<br>The maximum number of characters<br>is255.|
|StringChars [0]|2||Unicode character|
|StringChars [1]|2||Unicode character|
|||---||
|StringChars [N-1]|2|0x0000|Unicode character (null)|



## **7.3 Date Format** 

The character string representing the date complies with the following format. 

The date and time is shown in the form of the most significant value through the least significant value according to the format of ISO8601 standard.  This is a Unicode string format of “YYYYMMDDThhmmss” where YYYY is the year, MM is the month, DD is the day of the month, T is a constant character, hh is the hours, mm is the minutes, and ss is the seconds past the minute. The data is stored in the following array for the transmission/reception between the camera and the host. 

|Field|Size (Byte)|Data|Description|
|---|---|---|---|
|NumChar|1|0x10|Represents the number of characters in<br>the string.<br>The terminating null character is<br>included.<br>The number of characters in the string<br>representing the time is sixteen.|
|StringChars|32||Unicode string<br>“YYYYMMDDThhmmss”|



When the format setting is “YYYYMMDDThhmmss.xx”, the data following “YYYYMMDDThhmmss” should be ignored for use. 

## **7.4 Array Format** 

The array type complies with the following format.  Each field data is stored in the little endian format. 

|Field|Size (Byte)|Data|
|---|---|---|
|NumElement|4|The number of array elements is N (N is<br>the number of objects).|
|ArrayEntry [0]|ElementSize|ArrayData [0]|
|ArrayEntry [1]|ElementSize|ArrayData [1]|
|ArrayEntry [2]|ElementSize|ArrayData [2]|
|---|||
|ArrayEntry [N-1]|ElementSize|ArrayData [N-1]|



ElementSize: Data size of ArrayData 

Do Not Copy 

441/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **7.5 SBHandle** 

The SBHandle is used for identifying the flashes (the internal flash, external flash or other flash units) connected to the camera. 

The SBHandle takes an unsigned 32-bit value, and the unique number is assigned to each flash. 

## **7.6 SBGroupID** 

The SBGroupID is the ID number for identifying the flash group. 

|SBGroupID|Description|
|---|---|
|0x00000001|Master flash|
|0x00000002|Group A|
|0x00000004|GroupB|
|0x00000008|Group C|
|0x00000010|Group D|
|0x00000020|Group E|
|0x00000040|Group F|



Do Not Copy 

442/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **8 Ob ectHandle j** 

The ObjectHandle is used to represent the individual objects in the camera (image file, non-image file, directories, and the virtual association representing the relations of the images and the DCF objects conforming to the DCF standards). 

The ObjectHandle is unsigned 32 bits.  A unique value is set for the ObjectHandle indicating each object.  The specified ObjectHandle is fixed in one session. 

## **8.1 ObjectHandle of the Object Recorded in the Card** 

The camera sets a 4-byte unique value freely for the ObjectHandle created for the data in the card by the camera.  The host application does not care the contents. 

## **8.2 ObjectHandle of the Object Recorded in the SDRAM** 

The object recorded in the SDRAM is the image file only. 

The host can access the image data in the SDRAM by specifying the ObjectHandle passed by ObjectAddedInSdram. 

## **8.3 Addition of the ObjectHandle** 

The camera acts as shown below when an object is newly added to the card during one session. 

|No.|Description|
|---|---|
|1|In accordance with the ObjectHandle format defined in this section, the camera specifies a<br>unique ObjectHandle that is not coordinated with other ObjectHandles already specified for the<br>newly added object.|
|2|The camera sends the ObjectAdded event including the specified ObjectHandle as a<br>parameter to the host.  At this time, FreeSpaceInBytes and FreeSpaceInImages indicated in<br>the StorageInfo data set are updated immediately.|



Do Not Copy 

443/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9 DataSet** 

The camera transmits the information about the camera to the host by using some data sets. The data sets supported by the camera and their contents are shown below. 

## **9.1 DeviceInfo DataSet** 

The DeviceInfo data set is sent by the operation of the GetDeviceInfo command. Each field data is stored in the little endian format. 

The information sent by the DeviceInfo data set is shown below. 

|Field|Description|
|---|---|
|StandardVersion|The highest version of the standard that can support the device.|
|VendorExtensionID|The vendor extension ID used by the device.|
|VendorExtensionVersion|The vendor-specific version number of extensions that are supported.|
|VendorExtensionDesc|An optional string used to hold a human-readable description of the<br>VendorExtensionID.|
|FunctionalMode|An optional field used to hold the functional mode.|
|OperationsSupported|An array of OperationCodes supported by the camera.|
|EventsSupported|Anarray of EventCodes supported by the camera.|
|DevicePropertiesSupported|An array of DevicePropCodes supported by the camera.|
|CaptureFormats|An array of ObjectFormatCodes that can be created by the camera<br>with InitiateCapture.|
|ImageFormats|An array of ObjectFormatCodes supported by the camera.|
|Manufacture|An optional human-readable string used to indicate the device<br>manufacturer.|
|Model|An optional human-readable string used to indicate the device name.|
|DeviceVersion|An optional human-readable string used to indicate the version of the<br>device.|
|SerialNumber|An optional human-readable string used to indicate the serial number<br>ofthe camera.|



|Field|Size<br>(Byte)|Data|DataType|Description|
|---|---|---|---|---|
|StandardVersion|2|0x0064||Version 1.00|
|VendorExtensionID|4|0xFFFFFFFF||-|
|VendorExtensionVersion|2|0x006E||Version 1.10|
|VendorExtensionDesc|69|0x22<br>0x4D00<br>0x6900<br>0x6300<br>0x7200<br>0x6F00<br>0x7300<br>0x6F00<br>0x6600<br>0x7400<br>0x2E00<br>0x6300<br>0x6F00<br>0x6D00<br>0x2F00<br>0x4400<br>0x6500<br>0x7600<br>0x6900<br>0x6300<br>0x6500<br>0x5300|String|UNICODE character string<br>“Microsoft.com/DeviceServices: 1.0”|



Do Not Copy 

444/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

|**Confidential**||||**Nikon Corporation**|
|---|---|---|---|---|
|||0x6500<br>0x7200<br>0x7600<br>0x6900<br>0x6300<br>0x6500<br>0x7300<br>0x3A00<br>0x2000<br>0x3100<br>0x2E00<br>0x3000<br>0x0000|||
|FunctionalMode|2|0x0000||Normal mode|
|OperationsSupported|174|0x00000055<br>0x1001<br>0x1002<br>0x1003<br>0x1004<br>0x1005<br>0x1006<br>0x1007<br>0x1008<br>0x1009<br>0x100A<br>0x100B<br>0x100E<br>0x100F<br>0x1014<br>0x1015<br>0x1016<br>0x101B<br>0x90C0<br>0x90C1<br>0x90C2<br>0x90C3<br>0x90C4<br>0x90C7<br>0x90C8<br>0x90C9<br>0x90CA<br>0x90CB<br>0x90CC<br>0x90CD<br>0x90CE<br>0x90CF<br>0x9201<br>0x9202<br>0x9203<br>0x9204<br>0x9205<br>0x9206<br>0x9207<br>0x9209<br>0x920A<br>0x920B<br>0x920C<br>0x920F<br>0x9400<br>0x9402<br>0x9403<br>0x9404<br>0x9405<br>0x9406<br>0x940C<br>0x9414<br>0x9415|Array|OperationCode supported by the camera<br>This varies depending on whether the<br>connection destination is MTP or not.<br>MTP:<br>0x100C Not supported<br>0x100D Not supported<br>Other than MTP:<br>0x9801 Not supported<br>0x9802 Not supported<br>0x9803 Not supported<br>0x9805 Not supported|



Do Not Copy 

445/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

|**Confidential**||||**Nikon Corporation**|
|---|---|---|---|---|
|||0x9416<br>0x9417<br>0x9418<br>0x9419<br>0x941A<br>0x941B<br>0x941C<br>0x9420<br>0x9421<br>0x9422<br>0x9423<br>0x9424<br>0x9425<br>0x9426<br>0x9428<br>0x9431<br>0x9432<br>0x9433<br>0x9434<br>0x9435<br>0x9436<br>0x9520<br>0x9521<br>0x9522<br>0x9523<br>0x9527<br>0x9528<br>0x9529<br>0x9530<br>0x9801<br>0x9802<br>0x9803<br>0x9805|||
|EventsSupported|56|0x0000001A<br>0x4001<br>0x4002<br>0x4003<br>0x4004<br>0x4005<br>0x4006<br>0x4007<br>0x4008<br>0x4009<br>0x400A<br>0x400C<br>0x400D<br>0xC101<br>0xC102<br>0xC105<br>0xC108<br>0xC10A<br>0xC10B<br>0xC10C<br>0xC10D<br>0xC10E<br>0xC120<br>0xC121<br>0xC122<br>0xC123<br>0xC700|Array|EventCode supported by the camera|
|DevicePropertiesSuppor<br>ted|46|0x00000015<br>0x5001<br>0x5003<br>0x5004<br>0x5005<br>0x5007<br>0x5008|Array|DevicePropertyCode supported by the<br>camera<br>The vendor codes are not enumerated in this<br>field.<br>The vendor codes can be acquired by the<br>GetVendorPropCodes command (subsection|



Do Not Copy 

446/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

|**Confidential**||||**Nikon Corporation**|
|---|---|---|---|---|
|||0x500A<br>0x500B<br>0x500C<br>0x500D<br>0x500E<br>0x500F<br>0x5010<br>0x5011<br>0x5013<br>0x5018<br>0x501E<br>0x501F<br>0xD303<br>0xD406<br>0xD407||6.2.2.1).|
|CaptureFormats|8|0x00000002<br>0x3801<br>0x3800|Array|ObjectFormatCode that can be created by<br>the camera with InitiateCapture<br>This varies depending on whether the<br>connection destination is MTP or not.<br>MTP:<br>0x3000 Not supported<br>Other than MTP:<br>0x3800Not supported|
|ImageFormats|18|0x00000007<br>0x3801<br>0x3800<br>0x3001<br>0x380D<br>0x3000<br>0x300D<br>0xB982|Array|ObjectFormatCode supported by the camera<br>This varies depending on whether the<br>connection destination is MTP or not.<br>MTP:<br>0x3002 Not supported<br>Other than MTP:<br>0x3800 Not supported|
|Manufacture|37|0x12<br>0x4E00<br>0x6900<br>0x6B00<br>0x6F00<br>0x6E00<br>0x2000<br>0x4300<br>0x6F00<br>0x7200<br>0x7000<br>0x6F00<br>0x7200<br>0x6100<br>0x7400<br>0x6900<br>0x6F00<br>0x6E00<br>0x0000|String|UNICODE character string<br>“Nikon Corporation”|
|Model|13|0x06<br>0x5A00<br>0x2000<br>0x3600<br>0x5F00<br>0x3200<br>0x0000|String|UNICODE character string<br>“D 6_2”|
|DeviceVersion|13|0x06<br>0x5600<br>0x3100<br>0x2E00<br>0x3000<br>0x3000<br>0x0000|String|UNICODE character string<br>“V1.00”|
|SerialNumber|67|0x21<br>0xXX00<br>0xXX00|String|UNICODE character string<br>“XXXXXXXXXXXXXXXXXXXXXXXXXXXXX<br>XX”|



Do Not Copy 

447/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0xXX00 0x0000 

Do Not Copy 

448/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.2 StorageInfo DataSet** 

The StorageInfo data set is sent by the operation of the GetStorageInfo command. This data set indicates information about the storage medium (card). Each field data is stored in the little endian format. 

Information sent by the StorageInfo data set is shown below. 

|Field|Description|
|---|---|
|StorageType|Indicates the type ofthe card.  RemovableRam is set.|
|FilesystemType|Indicates the filesystem of the card.  It conforms to the DCF.|
|AccessCapability|Indicates the access right for the card.<br>When the card is not locked, it is read-only and the image deletion is<br>allowed.<br>When the card is locked, it is read-only and the image deletion is not<br>allowed.|
|MaxCapacity|Indicates the capacity of the card.  It depends on the card used.|
|FreeSpaceInBytes|Indicates the free space in the card.  It depends on the card used and<br>the space that is currently used.|
|FreeSpaceInImages|Indicates the number of images that can be recorded in the free space<br>of the card.<br>It is the number of images captured in the mode that is currently set in<br>the camera.<br>It depends on the card used and the space that is currently used.|
|StorageDescription|Indicates a human-readable text description of the card.  This field is<br>not usedforthe camera.|
|VolumeLabel|Indicates the volume label of the card.<br>It is described in a human-readable character string (Unicode<br>characterstring).|



|Field|Size (Byte)|Data|DataType|Description|
|---|---|---|---|---|
|StorageType|2|0x0004||Removable Ram|
|FilesystemType|2|0x0003||Based on the DCF|
|AccessCapability|2|0x0002<br>0x0001 (Card lock)||Read-Only with Object Deletion<br>Read-Only without Object Deletion (Card lock)|
|MaxCapacity|8|||Depends on the card.|
|FreeSpaceInBytes|8|||Depends on the card and the space used.|
|FreeSpaceInImages|4|||Depends on the card and the space used.|
|StorageDescription|1|0x00||-|
|VolumeLabel|||String|Unicode character string|



Do Not Copy 

449/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.3 ObjectInfo DataSet** 

The ObjectInfo data set is sent by the operation of the GetObjectInfo command. This data set indicates information about the objects in the card. Each field data in which the data type is not specified is stored in the little endian format. 

|Field|Description|
|---|---|
|StorageID|Indicates the StorageID of the card.|
|ObjectFormat|Indicates the ObjectFormatCode of the object.|
|ProtectionStatus|Indicates the protection status of the object.|
|ObjectCompressedSize|Indicates the size of the object in bytes.<br>0xFFFFFFFF for over 4GB.|
|ThumbFormat|Indicates the ObjectFormat of the thumbnail.|
|ThumbCompressedSize|Indicates the size of the thumbnail in bytes.|
|ThumbPixWidth|Indicates the thumbnail width inpixels.|
|ThumbPixHeight|Indicates the thumbnail height in pixels.|
|ImagePixWidth|Indicates theimagewidth inpixels.|
|ImagePixHeight|Indicates the image height in pixels.|
|ImageBitDepth|Indicates the bit depth of the image.|
|ParentObject|Indicates the ObjectHandle of the parent object of this object.|
|AssociationType|Indicates the association type.<br>It is used for the object of the association type.|
|AssociationDesc|Indicates the descriptor parameter of the association.<br>It is not used in the camera.|
|SequenceNumber|Indicates the component of the association.<br>Itisnot usedinthe camera.|
|Filename|Indicates an optional character string showing the file name of the<br>object.|
|CaptureDate|Indicates the character string showing the date and time of object<br>creation.|
|ModificationDate|Indicates the character string showing the date and time of object<br>modification.<br>When the object does not have a date and time of modification, the<br>same date and time as that of the object creation is stored.|
|Keywords|Indicates the character string showing the image-related keyword.<br>It is not used in the camera.|



Do Not Copy 

450/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.3.1 Directory/Virtual Association DataSet** 

|Field|Size<br>(Byte)|Data|DataType|Description|
|---|---|---|---|---|
|StorageID|4|StorageID||StorageID|
|ObjectFormat|2|0x3001||Association (Refer to ObjectFormatCode.)|
|ProtectionStatus|2|0x0000||-|
|ObjectCompressedSize|4|0x00000000||-|
|ThumbFormat|2|0x0000||-|
|ThumbCompressedSize|4|0x00000000||-|
|ThumbPixWidth|4|0x00000000||-|
|ThumbPixHeight|4|0x00000000||-|
|ImagePixWidth|4|0x00000000||-|
|ImagePixHeight|4|0x00000000||-|
|ImageBitDepth|4|0x00000000||-|
|ParentObject|4|ObjectHandle||ObjectHandle of the parent directory<br>DCIM folder: 0x00000000|
|AssociationType|2|0x0001||GenericFolder|
|AssociationDesc|4|0x00000000||-|
|SequenceNumber|4|0x00000000||-|
|Filename|||String|Unicode character string|
|CaptureDate|||String|Date<br>and<br>time<br>of<br>capture<br>(Unicode<br>character string)<br>(Not used for the virtual association)|
|ModificationDate|||String|Date and time of modification (Unicode<br>character string)<br>(Not used for the virtual association)|
|Keywords|1|0x00||-|



Do Not Copy 

451/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.3.2 Image File DataSet** 

|Field|Size<br>(Byte)|Data|DataType|Description|
|---|---|---|---|---|
|StorageID|4|StorageID||StorageID<br>SDRAM image: 0x00000000|
|ObjectFormat|2|||0x3000 (Undefined)<br>0x3801 (EXIF)<br>0x380D (TIFF)|
|ProtectionStatus|2|||0x0001 (with protection setting),<br>0x0000 (without protection setting)|
|ObjectCompressedSize|4|||File size|
|ThumbFormat|2|0x3808||JFIF (Refer to ObjectFormatCode.)|
|ThumbCompressedSize|4|||Thumbnailsize|
|ThumbPixWidth|4|0x000000A0||Horizontal size of the thumbnail (160)|
|ThumbPixHeight|4|0x00000078||Vertical size of the thumbnail (120)|
|ImagePixWidth|4|||Horizontal size of the main image|
|ImagePixHeight|4|||Vertical size of the main image|
|ImageBitDepth|4|0x00000000||-|
|ParentObject|4|ObjectHandle||ObjectHandle of the parent directory|
|AssociationType|2|0x0000||-|
|AssociationDesc|4|0x00000000||-|
|SequenceNumber|4|0x00000000||-|
|Filename|||String|File name character string (Unicode character<br>string)<br>“File name.extension” is set for the images<br>recorded in the card with the recording<br>destination set to “Card” or “Card and SDRAM”.<br>“DSC_0000.extension” is set for the images<br>whose recording destination is the SDRAM.<br>For the images recorded in the SDRAM with the<br>recording destination set to “Card and SDRAM”,<br>the name including the folder name and the file<br>name of the image recorded in the card<br>simultaneously is set.  “Folder<br>name¥(backslash)file name.extension”.  If the<br>image deletion is performed by operating the<br>camera during the card recording while “Card<br>and SDRAM” recording is set in the application<br>mode, the file name of the image with the<br>recording destination SDRAM may be<br>“DSC_0000.extension” in some cases.<br>When the object format is “Undefined”, the<br>extension is NEF (RAW) or NDF (dust reference<br>image).|
|CaptureDate|||String|Date and time of capture (Unicode character<br>string)|
|ModificationDate|||String|Date and time of modification (Unicode character<br>string)|
|Keywords|1|0x00||-|



Do Not Copy 

452/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.3.3 Script File DataSet** 

|Field|Size (Byte)|Data|DataType|Description|
|---|---|---|---|---|
|StorageID|4|0x00000000|||
|ObjectFormat|2|0x3002||Script (Refer to ObjectFormatCode.)|
|ProtectionStatus|2|0x0000||No protection setting|
|ObjectCompressedSize|4|||File size|
|ThumbFormat|2|0x0000||-|
|ThumbCompressedSize|4|0x00000000||-|
|ThumbPixWidth|4|0x00000000||-|
|ThumbPixHeight|4|0x00000000||-|
|ImagePixWidth|4|0x00000000||-|
|ImagePixHeight|4|0x00000000||-|
|ImageBitDepth|4|0x00000000||-|
|ParentObject|4|0x00000000||-|
|AssociationType|2|0x0000||-|
|AssociationDesc|4|0x00000000||-|
|SequenceNumber|4|0x00000000||-|
|Filename|||String|File name (Unicode character string)<br>(“DDISCVRY.DPS”or“DREQUEST.DPS”)|
|CaptureDate|||String|Date and time of creation (Unicode character<br>string)|
|ModificationDate|||String|Date and time of modification (Unicode<br>character string)|
|Keywords|1|0x00||-|



Do Not Copy 

453/484 

**Confidential** 

## **Confidential** 

## **Nikon Corporation** 

## **9.3.4 Movie File DataSet** 

|Field|Size (Byte)|Data|DataType|Description|
|---|---|---|---|---|
|StorageID|4|StorageID||StorageID<br>Image:0x00000000|
|ObjectFormat|2|||0x300D (MOV)|
|ProtectionStatus|2|||0x0001 (with protection setting)<br>0x0000 (without protectionsetting)|
|ObjectCompressedSize|4|||File size|
|ThumbFormat|2|0x3808||JFIF(Referto ObjectFormatCode.)|
|ThumbCompressedSize|4|||Thumbnail size|
|ThumbPixWidth|4|0x000000A0||Horizontal size of the thumbnail (160)|
|ThumbPixHeight|4|0x00000078||Vertical size of the thumbnail (120)|
|ImagePixWidth|4|||Horizontal size of the main movie|
|ImagePixHeight|4|||Verticalsize ofthemain movie|
|ImageBitDepth|4|0x00000000||-|
|ParentObject|4|ObjectHandle||ObjectHandle of the parent directory|
|AssociationType|2|0x0000||-|
|AssociationDesc|4|0x00000000||-|
|SequenceNumber|4|0x00000000||-|
|Filename|||String|File name character string (Unicode character<br>string)<br>“Filename.MOV”|
|CaptureDate|||String|Date and time of capture (Unicode character<br>string)|
|ModificationDate|||String|Date and time of modification (Unicode character<br>string)|
|Keywords|1|0x00||-|



Do Not Copy 

454/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.4 DevicePropDesc DataSet** 

The DevicePropDesc data set is sent by the operation of the GetDevicePropDesc command. This data set indicates information about the settings and the attribute of the device. Each field data in which the data type is not specified is stored in the little endian format. 

||Field|Field||Description|Description|Description|
|---|---|---|---|---|---|---|
||DevicePropCode|||Indicates DevicePropCode of the property.|||
||DataType|||Indicates the data type of the property.|||
||GetSet|||Indicates the access attribute of the property.|||
||Factory Default Value|||Indicates the default value of the property.|||
||CurrentValue|||Indicates the currentvalue ofthe property.|||
||FormFlag|||Indicates the property description data set.|||
||||||||
||Field|Size (Byte)||Data|DataType|Description|
|DevicePropertyCode||2|DevicePropCode|||DevicePropCode supported by the camera|
|DataType||2||||Indicates the data type of the property.<br>It differs depending on each property.<br>Refer to DataTypeCode (subsection 7.1).|
|GetSet||1||||Indicates whether the property is for reading<br>only or for both reading and writing.<br>0x00: Reading only (Get)<br>0x01: Reading/writing (Get/Set)|
|FactoryDefaultValue||DTS||||Default value.<br>It differs depending on each property.|
|CurrentValue||DTS||||Current value.<br>It differs depending oneachproperty.|
|FormFlag||1||||Indicates the property description data set.<br>0x00: None<br>0x01: Range<br>0x02: Enumeration|
|FORM||DTS||||The contents of the field depend on the<br>FormFlag field.<br>It does not exist when the FormFlag field is<br>set to 0.|



Do Not Copy 

455/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.5 ObjectPropDesc DataSet** 

The ObjectPropDesc data set is sent by the operation of the GetObjectPropDesc command. This data set indicates information about the settings and the attribute of the object. Each field data in which the data type is not specified is stored in the little endian format. 

|Field|Description|
|---|---|
|ObjectPropertyCode|Indicates ObjectPropCode of the property.|
|DataType|Indicates the data type of the property.|
|GetSet|Indicates the access attribute of the property.|
|Default Value|Indicates the default value of the property.|
|Group Code|Indicates the searchgroup ofthe property.|
|FormFlag|Indicates the property description data set.|



|Field|Size (Byte)|Data|DataType|Description|
|---|---|---|---|---|
|ObjectPropertyCode|2|ObjectPropCode|UINT16|ObjectPropCode supported by the camera|
|DataType|2|DataTypeCode|UINT16|Indicates the data type of the property.<br>It differs depending on each property.<br>RefertoDataTypeCode (subsection 7.1).|
|GetSet|1||UINT8|Indicates whether the property is for reading<br>only or for both reading and writing.<br>0x00: Reading only (Get)<br>0x01: Reading/writing (Get/Set)|
|DefaultValue|DTS|||The default value in the camera.<br>It differs depending on each property.|
|Group Code|4||UINT32|Search group|
|FormFlag|1||UINT8|Indicates the property description data set.<br>0x00: None<br>0x01: Range<br>0x02: Enumeration<br>0x03: Time<br>0x04: Fixed-length array<br>0x05: Regular expression<br>0x06: Byte string<br>0xFF: LongString|
|FORM|DTS|||The contents of the field depend on the<br>FormFlag field.<br>It does not exist when the FormFlag field is<br>set to 0.|



Do Not Copy 

456/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.6 Property Description DataSet** 

The property description data set is set in the FORM field of the DevicePropDesc data set and the ObjectPropDesc data set. 

## **9.6.1 Range Form** 

|Field|Size (Byte)|Description|
|---|---|---|
|MinimumValue|DTS|Theminimum value supported by thePropertyValue|
|MaximumValue|DTS|The maximum value supported by the PropertyValue|
|StepSize|DTS|The property supports the value indicated as shown below.<br>MinimumValue + N x StepSize<br>* N: From 0 to the maximum value<br>*PropertyValue: Smaller than the Maximum Value|



## **9.6.2 Enumeration Form** 

|Field|Size (Byte)|Description|
|---|---|---|
|NumberOfValue|2|Indicates the number of values of the PropertyValue supported by the property.|
|SupportedValue1|DTS|The property supports this PropertyValue.|
|SupportedValue2|DTS|The property supports thisPropertyValue.|
|SupportedValue3|DTS|The property supports this PropertyValue.|
|||---|
|SupportedValueM|DTS|The property supports this PropertyValue.|



## **9.6.3 Time Form** 

For the time form, the FORM field does not exist. 

The time form is represented by a Unicode character string in the ISO standard format.  (Refer to ISO8601.) 

||YYYYMMDDThhmmss.s|
|---|---|
|YYYY|Year|
|MM|Month (from 01 to 12)|
|DD|Date (from01to 31)|
|T|Fixed character|
|hh|Hourstartingfrom0 a.m.(from00 to23)|
|mm|Minutes (from 00 to 59)|
|ss.s|Seconds|



Do Not Copy 

457/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.6.4 Fixed-Length Array Form** 

|Field|Size (Byte)|Description|
|---|---|---|
|Length|2|It is an unsigned 16-bit integer and indicates the number of<br>array elements.|



## **9.6.5 Regular Expression Form** 

|Field|Size (Byte)|Description|
|---|---|---|
|RegEx|DTS|It indicates the regular expression for creating the<br>PropertyValue correctly.|



## **9.6.6 Byte String Form** 

|Field|Description|
|---|---|
|MaxLength|Itindicates themaximum lengthofthe byte string.|



## **9.6.7 LongString Form** 

|Field|Description|
|---|---|
|MaxLength|It indicates the maximum length of the LongString.  The property includes the data<br>type of AUINT16.<br>(Characters coded by2-byte Unicode characters as definedin ISO10646.)|



Do Not Copy 

458/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.7 LiveViewObject DataSet** 

## **9.7.1 DataSet with Version** 

||Field|Field|Field|Size|Description|
|---|---|---|---|---|---|
|Display information|Version|||2Byte|Major version (0x01)|
|||||2Byte|Minor version (0x00)|
||Reserved|||4Byte||
||Display information area size|||4Byte||
||Live view image area size|||4Byte||
||Whole size||Horizontal<br>size|2Byte|Standard of the coordinates|
||||Vertical<br>size|2Byte||
||Display area size||Horizontal<br>size|2Byte|The whole size is equal to the display area<br>size when the image is not enlarged.|
||||Vertical<br>size|2Byte||
||Display center coordinates||Horizontal<br>size|2Byte||
||||Vertical<br>size|2Byte||
||Live view image<br>Image size||Horizontal<br>size|2Byte|The size set in the LiveViewImageSize<br>property becomes the image size.|
||||Vertical<br>size|2Byte||
||Live view image<br>Quality|||1Byte|The quality is set in the<br>LiveViewImageCompressionproperty.|
||Reserved|||7Byte||
||AF driving enabled status|||1Byte|0: AF driving disabled, 1: AF driving enabled|
||Focus driving status|||1Byte|0: Not driving, 1: Driving|
||Focusing judgement result|||1Byte|0: No information, 1: Not focused,<br>2: Focused|
||AF mode state|||1Byte|0: Other<br>1: Face (eye, animal) detection AF<br>2: Auto-area AF|
||AF area number|||1Byte|From 0 to 42 (The number of faces when<br>using face-priority AF)|
||Selected face index|||1Byte|From 0 to 34|
||Tracking state|||1Byte|0: Waiting<br>1: Targeting<br>2: Tracking|
||Reserved|||1Byte||
||From 0<br>to 41|AF frame size|Horizontal<br>size|2Byte|Region of the AF frame size and the AF frame<br>center coordinates for 42 areas.|
||||Vertical<br>size|2Byte||
|||AF frame<br>center<br>coordinates|Horizontal<br>size|2Byte||
||||Vertical<br>size|2Byte||
||Remaining time of movie recording|||4Byte|From 0 to 1799999 [msec]<br>* It is valid during the movie recording state.|
||Sound indicator<br>(peak value)||L|1Byte|From 0 to 14|
||||R|1Byte|From0 to14|
||Sound indicator<br>(current value)||L|1Byte|From 0 to 14|
||||R|1Byte|From 0 to 14|
||Movie recording information|||1Byte|0: During LV execution<br>1: During movie recording|
||State of synchronous recording by the<br>external recorder(NOTE1)|||1Byte|0: Synchronous recording cannot be<br>performed|



Do Not Copy 

459/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

|||||**Nikon Corporation**|
|---|---|---|---|---|
|||||1: Synchronous recording standby<br>(Synchronous recording can be performed<br>but does not start)<br>2: Synchronous recording is being performed|
||Reserved||1Byte||
||Time code status||1Byte|0: Off, 1: On|
||Time code count||1Byte|Hour|
||||1Byte|Minute|
||||1Byte|Second|
||||1Byte|Frame|
||Countdown time||2Byte|Countdown every one second starting from<br>3600 (one hour) ; countdown starting from<br>thirty seconds with a rise in temperature|
||Spot WB condition||1Byte|0: Off<br>1: On standby (not acquired)<br>2: During acquisition operation<br>3: On standby (acquisition success)<br>4:Onstandby (acquisition failure)|
||Rotation||1Byte|0: Off, 1: Rotate counterclockwise,<br>2: Rotate clockwise, 3: Upside down|
||Level angle information|Rolling|4Byte||
|||Pitching|4Byte||
|||Yawing|4Byte||
||Using white balance for live<br>photography (NOTE1)|view|1Byte|0: Off<br>1: On|
||Reserved||95Byte||
|Live view image|Image data||||



NOTE1) Grayed out items are reserved in this camera and the value is fixed to zero. 

The data specifications for LiveViewObject (With Version) are shown below. 

|No.|Description|
|---|---|
|1|The size of the display information is 5121Byte.|
|2|When the electronic VR is ON, the image is 90% of angle of view.|



The values of AF frame size and AF frame center coordinates are shown below. 

|No.|Description|
|---|---|
|1|The AF frame size and the AF frame center coordinates for the number of [AF area number]<br>are valid.|
|2|When the AF area mode is [Wide-area AF (L-Person/L-Animal)] and the camera detects faces<br>(eyes/animals), the first area contains the AF frame size and AF frame center coordinates of<br>wide-area AF (L).<br>The second area and after contain the AF frame size and AF frame center coordinates at which<br>faces (eyes/animals) are detected.|



Refer to the following property about the value for virtual horizon. 

|No.|Description|
|---|---|
|1|AngleLevel property (subsection 6.5.7.20)|
|2|AngleLevelPitching property (subsection 6.5.7.21)|
|3|AngleLevelYawing property (subsection 6.5.7.22)|



The details of the AF mode state are shown below. 

|No.|Description|
|---|---|
|1|The AF mode state becomes [1:Face/Eye/Animal detect AF] under the following conditions.|



Do Not Copy 

460/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

- The AF area mode is [Auto-area AF (Person/Animal)] and the camera detects faces (eyes/animals). - The AF area mode is [Wide-area AF (L-Person/L-Animal)] and the camera detects faces (eyes/animals). The AF mode state becomes [2:Auto-area AF] under the following conditions. - The AF area mode is [Auto-area AF]. 2 - The AF area mode is [Auto-area AF (Person/Animal)] and the camera doesn't detect faces (eyes/animals). The AF mode state becomes [0:Other] under the following conditions. - When the conditions of No1 and No2 are not met. 3 Including the case when the AF area mode is [Wide-area AF (L-Person/L-Animal)] and the camera doesn't detect faces (eyes/animals). 

Do Not Copy 

461/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.7.2 DataSet without Version** 

||Field|Field||Size|Description|
|---|---|---|---|---|---|
||Display information area size|||4Byte||
||Live view image area size|||4Byte||
|Display information|Live view image<br>Image size||Horizontal<br>size|2Byte|The size set in the LiveViewImageSize<br>property becomes the image size.|
||||Vertical size|2Byte||
||Whole size||Horizontal<br>size|2Byte|Standard of the coordinates|
||||Vertical size|2Byte||
||Display area size||Horizontal<br>size|2Byte|The whole size is equal to the display area<br>size when the image is not enlarged.|
||||Vertical size|2Byte||
||Display center coordinates||Horizontal<br>size|2Byte||
||||Vertical size|2Byte||
||AF frame size||Horizontal<br>size|2Byte||
||||Vertical size|2Byte||
||AF frame center coordinates||Horizontal<br>size|2Byte||
||||Vertical size|2Byte||
||Reserved|||4Byte||
||Selected focus area|||1Byte|From 0 to 51|
||Rotation|||1Byte|0: Off, 1: Rotate counterclockwise,<br>2: Rotate clockwise, 3: Upside down|
||Focus driving status|||1Byte|0: Not driving, 1: Driving|
||Reserved|||1Byte||
||Reserved|||4Byte||
||Reserved|||2Byte||
||Countdown time|||2Byte|Countdown every one second starting from<br>3600 (one hour) ; countdown starting from<br>thirty seconds with a rise in temperature|
||Focusing judgement result|||1Byte|0: No information, 1: Not focused,<br>2: Focused|
||AFdriving enabled status|||1Byte|0: AFdriving disabled,1: AFdriving enabled|
||Reserved|||2Byte||
||Level angle information||Rolling|4Byte||
||||Pitching|4Byte||
||||Yawing|4Byte||
||Remaining time of movie recording|||4Byte|From 0 to 1799999 [msec]<br>* It is valid during the movie recording state.|
||Movie recording information|||1Byte|0: During LV execution<br>1: During movie recording|
||Face detection AF mode state|||1Byte|0: Face detection AF is not set.<br>1: Face (Eye/Animal) detection AF is set.|
||The number of persons whose faces are<br>detected|||1Byte|From 0 to 35|
||Selectedfaceindex|||1Byte|From0 to 34|
||0<br>to<br>34|AF frame size|Horizontal<br>size|2Byte|Area of the AF frame size and the AF frame<br>center coordinates for thirty-five persons<br>(4 Byte + 4 Byte) x 35 persons;<br>280 Byte in total|
||||Vertical size|2Byte||
|||AF<br>frame<br>center<br>coordinates|Horizontal<br>position|2Byte||
||||Vertical<br>position|2Byte||
||Sound indicator<br>(peak value)||L|1Byte|From 0 to 14|
||||R|1Byte|From 0 to 14|
||Sound indicator<br>(current value)||L|1Byte|From 0 to 14|
||||R|1Byte|From 0 to 14|
||Reserved|||1Byte||
||Reserved|||1Byte||



Do Not Copy 

462/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

||||**Nikon Corporation**|
|---|---|---|---|
||Reserved|1Byte||
||Spot WB condition|1Byte|0: Off<br>1: On standby (not acquired)<br>2: During acquisition operation<br>3: On standby (acquisition success)<br>4:Onstandby (acquisition failure)|
||Reserved|24Byte||
|Live view image|Image data|||



The data specifications for LiveViewObject (No Version) are shown below. 

|No.|Description|
|---|---|
|1|The size ofthe displayinformation is 376Byte.|
|2|When the electronic VR is ON, the image is 90% of angle of view.|



Refer to the following property about the value for virtual horizon. 

|No.|Description|
|---|---|
|1|AngleLevel property (subsection 6.5.7.20)|
|2|AngleLevelPitching property (subsection 6.5.7.21)|
|3|AngleLevelYawing property (subsection6.5.7.22)|



The details of the case in which the face detection AF mode state is set to “1: Face (Eye/Animal) detection AF is set” are shown below. 

|No.|Description|
|---|---|
|1|When the camera operates face detection AF, the face detection AF mode state is set to “1:<br>Face (Eye/Animal) detection AF” is set”, and AF frame size and AF center coordinate become<br>valid.|



Do Not Copy 

463/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8 PictureControl DataSet** 

PictureControl DataSet is sent by operation of SetPicCtrlData command or GetPicCtrlData command. 

PictureControl DataSet indicates information about a picture control. 

|Field|Size|Reference|
|---|---|---|
|BasePictureControl|2|9.8.1|
|RegistrationName|20|9.8.2|
|ApplyLevel|1|9.8.3|
|QuickSharpFlag|1|9.8.4|
|QuickSharp|1|9.8.5|
|Sharpening|1|9.8.6|
|MiddleRangeSharpening|1|9.8.7|
|Clarity|1|9.8.8|
|Contrast|1|9.8.9|
|Brightness|1|9.8.10|
|Saturation|1|9.8.11|
|Hue|1|9.8.12|
|FilterEffects|1|9.8.13|
|Toning|1|9.8.14|
|ToningDensity|1|9.8.15|
|CustomCurveFlag|1|9.8.16|
|CustomCurveData|0 or578|9.8.17|



The values for Sharpening, MiddleRangeSharpening, Clarity, Contrast, Brightness, Saturation, Hue and ToningDensity are shown below. 

|Value|Description|
|---|---|
|-128|Auto|
|-N|-N x0.25|
||・・・|
|-1|-0.25|
|0|0|
|1|0.25|
||・・・|
|N|N x 0.25|



Do Not Copy 

464/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8.1 BasePictureControl** 

These are the types of picture controls on which the custom picture control is based. If the picture control is pre-installed, this indicates the picture control. The value is zero for unused custom picture control. 

|Value|Description|
|---|---|
|1|Standard|
|2|Neutral|
|3|Vivid|
|4|Monochrome|
|5|Portrait|
|6|Landscape|
|7|Flat|
|8|Auto|
|101|Dream|
|102|Morning|
|103|Pop|
|104|Sunday|
|105|Somber|
|106|Drama|
|107|Silence|
|108|Bleach|
|109|Melancholic|
|110|Pure|
|111|Denim|
|112|Toy|
|113|Sepia|
|114|Blue|
|115|Red|
|116|Pink|
|117|Charcoal|
|118|Graphite|
|119|Binary|
|120|Carbon|



## **9.8.2 RegistrationName** 

This is the registration name of picture control. The size is fixed to 20Bytes (ASCII: 19Bytes + NULL). 

Do Not Copy 

465/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8.3 ApplyLevel** 

This is the degree of control for picture control. 

|Value|Description|
|---|---|
|0|0|
|10|10|
|20|20|
|30|30|
|40|40|
|50|50|
|60|60|
|70|70|
|80|80|
|90|90|
|100|100|



Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|0|||0<br>10<br>20<br>30<br>40<br>50<br>60<br>70<br>80<br>90<br>100||||



Do Not Copy 

466/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8.4 QuickSharpFlag** 

This is the state of the quick sharpening control for a picture control. 

If QuickSharpFlag is set to [Valid] when setting a picture control, the values of Sharpening, 

MiddleRangeSharpening and Clarity are ignored. 

|Value|Description|
|---|---|
|0|Invalid|
|1|Valid|



## **9.8.5 QuickSharp** 

This is the quick sharpening control for a picture control. 

|Value|Description|
|---|---|
|-128|Auto|
|-2|-2|
|-1|-1|
|0|0|
|1|1|
|2|2|



Available values for each picture control are shown below. If QuickSharpFlag is set to [Invalid] when setting a picture control, [Auto] cannot be set. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|From -2 to 2|-128<br>From-2 to 2||From -2 to 2||||



Do Not Copy 

467/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8.6 Sharpening** 

This is the sharpening control for a picture control. Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|-8<br>-4<br>0<br>4<br>8|-128 (When QuickSharp is set to [Auto])<br>From -12 to 36||||||



## **9.8.7 MiddleRangeSharpening** 

This is the middle-range sharpening control for a picture control. Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|-8<br>-4<br>0<br>4<br>8|-128 (When QuickSharp is set to [Auto])<br>From -20 to 20||||||



Do Not Copy 

468/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8.8 Clarity** 

This is the clarity control for a picture control. Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|-8<br>-4<br>0<br>4<br>8|-128 (When QuickSharp is set to [Auto])<br>From -20 to 20||||||



## **9.8.9 Contrast** 

This is the contrast control for a picture control. Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|-8<br>-4<br>0<br>4<br>8|-128<br>From -12 to 12||From -12 to 12||||



Do Not Copy 

469/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8.10 Brightness** 

This is the brightness control for a picture control. Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|0|From -6 to 6||0||||



## **9.8.11 Saturation** 

This is the saturation control for a picture control. Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|-8<br>-4<br>0<br>4<br>8|-128<br>From -12 to 12|0|From -12 to 12||0||



Do Not Copy 

470/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8.12 Hue** 

This is the hue control for a picture control. Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|0|From -12to12|0|From -12to12|0|||



## **9.8.13 FilterEffects** 

This is the filter effect for a picture control. 

|Value|Description|
|---|---|
|0|Off|
|1|Yellow|
|2|Orange|
|3|Red|
|4|Green|



Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|0||From0 to4|0||From0 to4||



Do Not Copy 

471/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8.14 Toning** 

This is the toning control for a picture control. 

If toning can be selected and toning is set to [B&W] when setting a picture control, the value of ToningDensity is ignored. 

|Value|Description|
|---|---|
|0|B&W|
|1|Sepia|
|2|Cyanotype|
|3|Red|
|4|Yellow|
|5|Green|
|6|Blue Green|
|7|Blue|
|8|Purple Blue|
|9|Red Purple|



Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|0||From0 to 9|0|||From0 to 9|



## **9.8.15 ToningDensity** 

This is the toning (density) control for a picture control. Available values for each picture control are shown below. 

|Auto|Standard<br>Vivid<br>Portrait<br>Landscape<br>Neutral<br>Flat|Monochrome|Dream<br>Morning<br>Pop<br>Sunday|Somber<br>Drama<br>Silence<br>Bleach<br>Melancholic<br>Pure<br>Denim<br>Toy|Sepia<br>Blue<br>Red<br>Pink|Charcoal<br>Graphite<br>Binary<br>Carbon|
|---|---|---|---|---|---|---|
|0||From 0 to 28|0||From 0 to 28||



Do Not Copy 

472/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.8.16 CustomCurveFlag** 

This is the state of custom curve for a picture control. [Valid] is available only for a custom picture control. 

|Value|Description|
|---|---|
|0|Invalid|
|1|Valid|



## **9.8.17 CustomCurveData** 

This is the custom curve data for a picture control. The data format for a custom curve is described in LUT Format (subsection 9.8.17.1). If the CustomCurveFlag is set to [Invalid], this is not used. 

## **9.8.17.1 LUT Format** 

The LUT data consists of the header (64 bytes) for use on the host and following 514 bytes (2 bytes x 257 points) lut data.  The header format is specified by the host (The stored location for such as the line point of the LUT to be sent, the data for reproducing the LUT at the time of reading). The camera does not care about the header contents.  However, since 2 bytes of the header is used for judging whether header data is present on the camera, it is necessary to set data in the header. 

The LUT format is as follows. 

|Byte|Description|
|---|---|
|From 0 to 63|Lut Header|
|64, 65|Data0|
|66, 67|Data1|
||・・・|
|576, 577|Data256|



As an example of the Lut header, the contents of the header set by the application made by Nikon are shown below. 

|Byte|Description|Range|
|---|---|---|
|1|ID (Byte1)|0x49|
|2|ID (Byte2)|0x30|
|3|Input Minimum (Black Point)|0-255|
|4|Input Maximum|0-255|
|5|OutputMinimum|0-255|
|6|Output Maximum|0-255|
|7|Gamma (integerportion)|0-20|
|8|Gamma (fractional portion)|0-100|
|9|Number of Spline Points|2-20|
|10,11|SplinePoint1(x, y)|0-255, 0-255|
|12, 13|Spline Point2 (x, y)|0-255, 0-255|
||・・・||
|48, 49|Spline Point20 (x, y)|0-255, 0-255|
|From50 to 64|Reserved|0|



Do Not Copy 

473/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.9 PictureControlCapability DataSet** 

The PictureControlCapability DataSet is sent by operation of GetPicCtrlCapability command. The PictureControlCapability DataSet indicates information about the function of a picture control. 

|Field|Size|Data|Description|
|---|---|---|---|
|ApplyLevelCapability|1|0x00:Not selectable<br>0x80:Selectable<br>0x01: AUTO is available<br>0x81:Selectable and<br>AUTO is available|Apply level: Selectability and availability of<br>AUTO|
|QuickSharpCapability|1||Quick sharpening: Selectability and availability<br>of AUTO|
|SharpeningCapability|1||Sharpening: Selectability and availability of<br>AUTO|
|MiddleRangeSharpening<br>Capability|1||Middle range sharpening: Selectability and<br>availability of AUTO|
|ClarityCapability|1||Clarity:Selectability and availability of AUTO|
|ContrastCapability|1||Contrast: Selectability and availability of<br>AUTO|
|BrightnessCapability|1||Brightness: Selectability and availability of<br>AUTO|
|SaturationCapability|1||Saturation: Selectability and availability of<br>AUTO|
|HueCapability|1||Hue: Selectability and availability of AUTO|
|FilterEffectsCapability|1||Filter effect: Selectability and availability of<br>AUTO|
|ToningCapability|1||Toning: Selectability and availability of AUTO|
|ToningDensityCapability|1||Toning (density): Selectability and availability<br>of AUTO|
|DefaultQuickSharpLevel|1|QuickSharp (9.8.5)|The default value of QuickSharp|
|DefaultLevel[0]|3|DefaultLevel (9.9.1)|QuickSharp-2|
|DefaultLevel[1]|3||QuickSharp-1|
|DefaultLevel[2]|3||QuickSharp 0|
|DefaultLevel[3]|3||QuickSharp+1|
|DefaultLevel[4]|3||QuickSharp+2|



## **9.9.1 DefaultLevel** 

The information for the default level used in the PictureControlCapability DataSet is shown below. 

|Field|Size|Reference|
|---|---|---|
|Sharpening|1|9.8.6|
|MiddleRangeSharpening|1|9.8.7|
|Clarity|1|9.8.8|



Do Not Copy 

474/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.10 SBAttributeDesc DataSet** 

The SBAttributeDesc data set is sent by the operation of the GetSBAttrDesc command or GetSBGroupAttrDesc command. 

The SBAttributeDesc data set is used to indicate the information of the flash attribute. 

The details of the SBAttributeDesc data set are shown below. 

|Field|Size (Byte)|DataType|Description|
|---|---|---|---|
|AttributeID|2|UINT16|SBAttrID or SBGroupAttrID|
|DataType|2|UINT16|Data type of the attribute<br>The value varies depending on the attribute.<br>Refer to DataTypeCode (subsection 7.1).|
|GetSet|1|UINT8|Availability of Get and Set operations.<br>0x00：Only Get operation is available (Get)<br>0x01：Get and Set operations are available (Get /<br>Set)|
|DefaultValue|DTS|DTS|The default value in the camera<br>The value varies depending on the attribute.|
|CurrentValue|DTS|DTS|The current value in the camera<br>The value varies depending on the attribute.|
|FormFlag|1|UINT8|Type of the data set descriptor<br>0x00：None<br>0x01：Range<br>0x02：Enumeration|
|FORM|DTS|DTS|The value in the field depends on FormFlag field.<br>If FormFlag is 0, this field doesn’t exist.|



## **9.11 SBAttributeDescList DataSet** 

The SBAttributeList data set is sent by the operation of the GetSBAttrValue command, the SetSBAttrValue command, the GetSBGroupAttrValue command or the SetSBGroupAttrValue command. 

The SBAttributeList data set is used to indicate the list of the current values of the flash attribute. 

The details of the SBAttributeList data set are shown below. 

|Field|Size (Byte)|DataType or DataSet|Description|
|---|---|---|---|
|NumberOfElements|4|UINT32|The number of attributes in the list.|
|Element1 AttributeDesc|DTS|Refer to SBAttributeDesc<br>(subsection9.10)|SBAttributeDesc for element 1|
|Element2 AttributeDesc|DTS|Refer to SBAttributeDesc<br>(subsection 9.10)|SBAttributeDesc for element 2|
||・・・|||
|ElementN AttributeDesc|DTS|Refer to SBAttributeDesc<br>(subsection 9.10)|SBAttributeDesc for element N|



Do Not Copy 

475/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **9.12 SBAttribute DataSet** 

The SBAttribute data set is sent by the operation of the GetSBAttrValue command, the SetSBAttrValue command, the GetSBGroupAttrValue command or the SetSBGroupAttrValue command. 

The SBAttribute data set is used to indicate the current values of the flash attribute. 

The details of the SBAttribute data set are shown below. 

|Field|Size (Byte)|DataType|Description|
|---|---|---|---|
|AttributeID|2|UINT16|SBAttrIDorSBGroupAttrID|
|DataType|2|UINT16|Data type of the attribute<br>The value varies depending on the attribute.<br>RefertoDataTypeCode (subsection 7.1).|
|CurrentValue|DTS|DTS|The current value in the camera<br>The value varies depending on the attribute.|



## **9.13 SBAttributeList DataSet** 

The SBAttributeList data set is sent by the operation of the GetSBAttrValue command, the SetSBAttrValue command, the GetSBGroupAttrValue command or the SetSBGroupAttrValue command. 

The SBAttributeList data set is used to indicate the list of the current values of the flash attribute. 

The details of the SBAttributeList data set are shown below. 

|Field|Size (Byte)|DataType or DataSet|Description|
|---|---|---|---|
|NumberOfElements|4|UINT32|The number of attributes in the list.|
|Element1 Attribute|DTS|Refer to SBAttribute<br>(subsection 9.12)|SBAttribute for element 1|
|Element2 Attribute|DTS|Refer to SBAttribute<br>(subsection 9.12)|SBAttribute for element 2|
||・・・|||
|ElementN Attribute|DTS|Refer to SBAttribute<br>(subsection 9.12)|SBAttribute for element N|



Do Not Copy 

476/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **10 Data Format** 

## **10.1 ASCII Codes** 

For the property related to the comment of the camera, only the following 90 characters of ASCII codes can be input. 

|SP|!|"|#|$|%|&|'|(|）|*|+|,|-|.|/|
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|:|;|<|=|>|?|@|[|]|_|{|}|||||
|0|1|2|3|4|5|6|7|8|9|||||||
|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|
|Q|R|S|T|U|V|W|X|Y|Z|||||||
|a|b|c|d|E|f|g|h|i|j|k|l|m|n|o|p|
|q|r|s|t|U|v|w|x|y|z|||||||



In addition to the above characters, following five characters can be used in the CommentString property (subsection 6.5.5.6), ArtistV property (subsection 6.5.5.8) and CopyrightV property (subsection 6.5.5.9). 

¥ ^ ` | ~ 

|||7-BitASCIICodeTable (JISRoman letterset:C0, GL)|7-BitASCIICodeTable (JISRoman letterset:C0, GL)|7-BitASCIICodeTable (JISRoman letterset:C0, GL)|7-BitASCIICodeTable (JISRoman letterset:C0, GL)|7-BitASCIICodeTable (JISRoman letterset:C0, GL)|7-BitASCIICodeTable (JISRoman letterset:C0, GL)||
|---|---|---|---|---|---|---|---|---|
||0x0?|0x1?|0x2?|0x3?|0x4?|0x5?|0x6?|0x7?|
|0x?0|NUL|DLE|SP|0|@|P|`|p|
|0x?1|SOH|DC1|!|1|A|Q|a|q|
|0x?2|STX|DC2|"|2|B|R|b|r|
|0x?3|ETX|DC3|#|3|C|S|c|s|
|0x?4|EOT|DC4|$|4|D|T|d|t|
|0x?5|ENQ|NAK|%|5|E|U|e|u|
|0x?6|ACK|SYN|&|6|F|V|f|v|
|0x?7|BEL|ETB|'|7|G|W|g|w|
|0x?8|BS|CAN|(|8|H|X|h|x|
|0x?9|HT|EM|)|9|I|Y|i|y|
|0x?a|LF|SUB|*|:|J|Z|j|z|
|0x?b|VT|ESC|+|;|K|[|k|{|
|0x?c|FF|FS|,|<|L|¥|l|||
|0x?d|CR|GS|-|=|M|]|m|}|
|0x?e|SO|RS|.|>|N|^|n|~|
|0x?f|SI|US|/|?|O|_|o|DEL|



Do Not Copy 

477/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **11 A endices pp** 

## **11.1 Properties Affected by Mounting the CPU Lens** 

The following properties are affected by mounting the CPU lens. 

|Property|Reference|
|---|---|
|LensSort|6.5.10.1|
|Fnumber|6.5.1.5|
|FocalLength|6.5.1.6|
|LensTypeML|6.5.10.2|
|LensTypeF|6.5.10.3|
|LensID|6.5.10.4|
|LensFocalMin|6.5.10.5|
|LensFocalMax|6.5.10.6|
|LensApatureMin|6.5.10.7|
|LensApatureMax|6.5.10.8|
|MovieFnumber|6.5.12.9|



## **11.2 Properties Affected by Mounting the External Flash** 

|Property|External flash mounted|External flash mounted|External flash not<br>mounted|
|---|---|---|---|
||New-type communication|Noncommunication||
|ExternalSpeedLightExist|Mounted|Mounted|Not mounted|
|ExternalSpeedLightSort|New-type communication|Noncommunication|Not fixed|
|ExternalSpeedLightStatus|Valid|Valid|Not fixed|
|NewExternalSpeedLightMode|Valid|Notfixed|Notfixed|
|FlashCompensation|Valid/Not fixed|Not fixed|Not fixed|
|ExposureTime|Bulb～ (*1) (*2)|Bulb～ (*1)|Bulb～1/8000|
|ShutterSpeed|Bulb～ (*1) (*2)|Bulb～ (*1)|Bulb～1/8000|



- *1: Flash shooting synchronization speed 

- *2: Speed limit of the external flash 

Do Not Copy 

478/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **11.3 Properties Affected by the Shooting Mode** 

|Property|Shooting mode|Shooting mode|Shooting mode|Shooting mode|
|---|---|---|---|---|
||M|P|A|S|
|ExposureProgramMode|M|P|A|S|
|Fnumber|Get / Set<br>(*1)|Get|Get / Set<br>(*1)|Get|
|ExposureTime|Get / Set|Get|Get|Get / Set<br>(*2)|
|ShutterSpeed|Get / Set|Get|Get|Get / Set|
|FlexibleProgram|Not fixed|Get / Set|Not fixed|Not fixed|



- *1: Setting is disabled when a lens other than the CPU lens is mounted. 

- *2: Setting is disabled with Bulb. 

Do Not Copy 

479/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **11.4 Properties Affected by Time Zone** 

The UTC is retained in the camera.  When displaying the time on the menu or getting/setting the DateTime property, “Time zone” and “Daylight saving time” in the camera are considered. 

When getting the DateTime property, the calculated value shown below is passed to the host. 

Time in the camera + Time zone difference + Daylight saving time 

When the camera settings are as shown in the table below, the calculation is “13:00:00 + 09:00 + 0:00” and the value passed to the host is “2006/06/01 22:00:00”. 

|Time in the camera (UTC)|2006/06/01 13:00:00|
|---|---|
|Time zone|UTC+9 (Tokyo, Seoul)|
|Daylight saving time|Off|



When the DateTime property is set, the value calculated as shown below is set in the camera. 

Time set by the host - Time zone difference - Daylight saving time 

When the camera settings are as shown in the table below and the time set by the host is “2006/06/01 13:00:00”, the calculation is “13:00:00 - 09:00 - 0:00” and the time setting in the camera is “2006/06/01 04:00:00”. 

|Time zone|UTC+9 (Tokyo, Seoul)|
|---|---|
|Daylight saving time|Off|



Do Not Copy 

480/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **11.5 White Balance Fine Tuning Coordinates** 

The relationship between the values of PropertyValue of the property affecting the white balance fine tuning and the actual setting coordinates is shown below. 

On the A-B axis: in steps of 0.5, on the G-M axis: in steps of 0.25 

**==> picture [331 x 340] intentionally omitted <==**

**----- Start of picture text -----**<br>
G<br>0 2 4 6 8 10 12 14 16 18 20 1122 24<br>1 00 102 104 106 108 110 112 114 116 118 120 122 12 4<br>2 00 202 204 206 208 210 212 214 216 218 220 222 22 4<br>3 00 302 304 306 308 310 312 314 316 318 320 322 32 4<br>4 00 402 404 406 408 410 412 414 416 418 420 422 42 4<br>5 00 502 504 506 508 510 512 514 516 518 520 522 52 4<br>B 600 602 604 606 608 610 612 614 616 618 620 622 624<br>7 00 702 704 706 708 710 712 714 716 718 720 722 72 4<br>8 00 802 804 806 808 810 812 814 816 818 820 822 82 4<br>9 00 902 904 906 908 910 912 914 916 918 920 922 92 4<br>10 00 1002 1004 1006 1008 1010 1012 1014 1016 1018 1020 1022 10 24<br>11 00 1102 1104 1106 1108 1110 1112 1114 1116 1118 1120 1122 11 24<br>1200 1202 1204 1206 1208 1210 1212 1214 1216 1218 1220 1222 1224<br>M<br>**----- End of picture text -----**<br>


A 

Do Not Copy 

481/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **11.6 External Flash Types** 

The communication status types of the external flash are shown below. 

|New-type<br>communication<br>(with the operating<br>and setting section)|New-type<br>communication<br>(without the<br>operating and<br>setting section)|Old-type<br>communication|Noncommunication|Mounting not<br>detected|
|---|---|---|---|---|
|SB-5000<br>SB-910<br>SB-900<br>SB-800<br>SB-700<br>SB-600<br>SU-800|SB-500<br>SB-400<br>SB-300|SB-80DX<br>SB-50DX<br>SB-28DX<br>SB-28D<br>SB-28<br>SB-27<br>SB-26<br>SB-25<br>SB-24|SB-30<br>SB-29<br>SB-29S<br>SB-23<br>SB-22<br>SB-22S<br>SB-21A<br>SB-21B<br>SB-20<br>SB-19<br>SB-18<br>SB-17<br>SB-16A<br>SB-16B<br>SB-15<br>SB-14<br>SB-12<br>SB-11<br>SB-10<br>SB-E|SB-9<br>SB-8<br>SB-7<br>SB-6<br>SB-5<br>SB-4<br>SB-3<br>SB-2<br>SB-1|



- *For old-type communication and noncommunication, mounting is not detected in the camera. 

Do Not Copy 

482/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **11.7 Command Release Operation** 

The operation by the command release is described in this subsection. 

## **11.7.1 Continuous Shooting** 

The number of images that can be captured continuously by the continuous shooting is the smallest number among the following property combination. 

|Property|Card|SDRAM|Card and SDRAM|
|---|---|---|---|
|BurstNumber(subsection 6.5.1.16)|`✓`|`✓`|`✓`|
|ContinuousShootingCount<br>(subsection6.5.7.6)|`✓`|`✓`|`✓`|



The availability of the continuous shooting in the release mode of StillCaptureMode (subsection 6.5.1.15) is described below. 

|Release mode|BurstNumber|Description|
|---|---|---|
|Singleframe|Invalid|Only oneimage canbe captured.|
|Continuous high-speed shot<br>Continuous low-speed shot<br>Continuous high-speed shot<br>(Extension)|Valid|Among the BurstNumber setting value, the number of images that can<br>be recorded in the SDRAM that is calculated in the camera, and the<br>number of remaining images for recording while the bracketing is<br>being performed, until the least number is reached, the acquisition of<br>the new objects can be performed.<br>Only one image can be captured when the internal flash is enabled or<br>the HDR mode is set.|
|Self-timer|Invalid|Only one image can be captured.<br>StillCaptureMode is temporarily set to the single frame when release.|



## **11.7.2 AF Operation** 

AF is performed in accordance with the setting of the FocusMode property (subsection 6.5.1.7). 

## **11.7.3 Preset WB acquisition** 

During live view photography, the preset WB acquisition is performed with release sequence. 

Refer to InitiateCaptureRecInMedia command about the preset measurement release. 

During movie live view, it is the same as the spot WB acquisition. 

Refer to StartSpotWb command. 

Do Not Copy 

483/484 

**Confidential** 

**Confidential** 

**Nikon Corporation** 

## **11.7.4 Event on the Release Operation** 

When the release operation is started, one or more new objects are created.  When the new objects are recorded, the camera generates the asynchronous interrupt event to inform the host of the addition of the new objects. 

The new object addition event includes the ObjectHandle indicating the new object that is created. If two or more new objects are created, the new object addition event is issued two or more times. When all the new objects that can be acquired are recorded, the camera issues the capturing completion event to the host to inform that the acquisition of all the new objects is completed. 

The new object addition event and the capturing completion event vary depending on the recording destination.  The following table shows the correspondence of the destination to the event. 

|Recording destination|New object addition event|Capturing completion event|
|---|---|---|
|Card|ObjectAdded|CaptureComplete|
|SDRAM|ObjectAddedInSdram|CaptureCompleteInSdram|
|Card and SDRAM|ObjectAdded and<br>ObjectAddedInSdram|CaptureComplete and<br>CaptureCompleteInSdram|



When the recording destination is set to [Card and SDRAM], the order of issuing the new object addition event is not decided and the events are issued in order of completing image recording. 

The capturing completion event is issued in the same way; the event of the recording destination in which acquisition of all the new objects is completed first, is issued first. 

## **11.7.5 Recovery from the Sequence Error** 

When the Bit0 of the WarningStatus property (subsection 6.5.7.23) is set to 1 [Sequence error] and the release operation is performed by the command, the sequence error is cancelled if the sequence error can be recovered.  When it is cancelled, the release is not started and the command is terminated. 

## **11.7.6 Silent Shooting** 

If the SilentPhotography property is set to [On] during live view photography, the silent shooting is performed. 

The number of images that can be captured continuously by the silent shooting is the least number among the following values: 

- The value of the BurstNumber property (subsection 6.5.1.16). 

- The value of the ContinuousShootingCount property (subsection 6.5.7.6). 

Do Not Copy 

484/484 

**Confidential** 

