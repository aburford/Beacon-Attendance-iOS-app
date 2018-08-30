# Beacon-Attendance-iOS-app
Part of my Beacon Attendance project. See the other two pieces: https://github.com/aburford/cryptobeacon and https://github.com/aburford/beacon_api
# So how does this work?
This app uses Bluetooth Beacon technology to detect when the student's phone is located inside the right classroom at the beginning of class. If the beacon is in range, the phone will tell a backend server to mark the student as present.

The beacon_api repo contains the code for the backend server, written in Ruby on Rails. Although not yet implemented, the attendance records on this server would theoretically be synced with PowerSchool, the system my high school uses for attendance.

The cryptobeacon repo contains a bash script that runs on a raspberry pi with BLE capability to create a Bluetooth Beacon. See here to learn what a beacon is: http://www.ibeacon.com/what-is-ibeacon-a-guide-to-beacons/

Beacons advertise a very limited amount of data, and this data typically remains static. They were not desgined for location verification since by design it is extremely simple to spoof a beacon. However, the beacon API's offered by iOS make this technology the most efficient and elegant way to verify a student's location in class.

That is why I came up with a system which uses cryptographic hashes to securely verify the student's location in the classroom. The Raspberry Pi beacon will dynamically generate hashes from the data unique to an attendance record: the current time, date, room number, and tardiness level (present, tardy, tardy w/o credit).

These hashes are advertised as the UUID, major, and minor values of the beacon. On the backend server, identical hashes are generated. These hashes are sent to the phone app on a daily basis so iOS can listen for these beacons throughout the school day. Each beacon hash will only be advertised in one specific classroom for the specific time interval corresponding to a specific tardiness level and will never be repeated.

Salt is hard coded into each individual beacon and saved in the backend to prevent students from simply generating the hash themselves.

The iOS app implements certificate pinning to prevent any modification or repudiation of requests. Bearer authentication for every request also ensures students can't create their own valid server requests by looking at the source code.

Despite all of this, a jailbroken iPhone can use this tweak to break the whole system: https://github.com/nabla-c0d3/ssl-kill-switch2.

In theory, if this was released on the app store we could try to make the minimum required OS version greater than that of the latest jailbreakable version, but even then applications like hopper (https://www.hopperapp.com) could be used to disable certificate pinning, obtain the bearer token, and break everything again.
