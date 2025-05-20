function sendTrigger(ioObj, address, triggerCode)
    io64(ioObj, address, triggerCode);
    WaitSecs(0.005);
    io64(ioObj, address, 0);
end