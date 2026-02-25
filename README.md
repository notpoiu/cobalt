<div align="center">
  
![image](https://github.com/user-attachments/assets/d88e0da7-0f48-46d0-86c2-5e721fa350c9)

A **runtime** developer tool for the **Roblox Game Engine** to monitor and

intercept incoming and outgoing network traffic with beautiful opinionated UI.

```lua
-- https://discord.gg/FJcJMuze7S
loadstring(game:HttpGet("https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau"))()
```

</div>

## Features

- Beautiful opinionated ui
- Incoming & Outgoing Event **monitoring**
  - Actors support\*
  - \_\_index hooking
  - UnreliableRemoteEvent Support
- Incoming & Outgoing Event **interception**
  - Block events
  - Replay events
- Pagination Implementation (prevents lag)
- Copy Calling and Intercept code
- File Logs
- Plugin System (https://docs.mspaint.cc/cobalt/plugins/overview)

> \*Actors are supported even on executors that lack the `run_on_actor` function. As long as the `setfflag` and `getfflag` functions are available in the executor's environement

## Video Demo

[![Cobalt Remote Spy Demo](http://img.youtube.com/vi/Ellj_P6-yVI/0.jpg)](http://www.youtube.com/watch?v=Ellj_P6-yVI)

# Development

For development instructions, please refer to [our documentation](https://docs.mspaint.cc/cobalt/development).
