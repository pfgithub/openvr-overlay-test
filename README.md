openvr overlay sample project

https://www.youtube.com/watch?v=r6kM3tR03g4

followed to about 45:05

- the thing doesn't track to the controller?
- but it's getting the controller id?
- and it's def calling the set position relative fn
- because changing the matrix changes the rotation of the thing in vr
- confused

---

building: (on windows x86\_64)

install zig (tested with version `0.11.0-dev.863+4809e0ea7`)
run setup:

```
mkdir -p zig-out/bin/
cp lib/openvr/bin/win64/openvr_api.dll zig-out/bin/
```

build and run application:

```
# through WSL, on windows
zig build run -Dtarget=native-windows

# natively, on windows or linux
zig build run
```

other platforms:

- it might work on linux-x86\_64 but it probably tries to statically link openvr
