let timer = null;
let startTime = null;
let remainingSeconds = 0;
let isPaused = false;
let lastTickTime = null;

// Function to check if we need to adjust the timer due to device sleep
function checkTimerAccuracy() {
  if (!isPaused && startTime && lastTickTime) {
    const now = Date.now();
    const expectedElapsed = now - lastTickTime;
    
    // If more than 2 seconds have passed since the last tick (should be ~1s)
    // then the device likely went to sleep or the tab was inactive
    if (expectedElapsed > 2000) {
      console.log(`Timer drift detected: ${expectedElapsed}ms elapsed since last tick`);
      
      // Calculate how many seconds we need to subtract
      const missedSeconds = Math.floor(expectedElapsed / 1000);
      if (missedSeconds > 0) {
        console.log(`Adjusting timer by ${missedSeconds} seconds`);
        remainingSeconds = Math.max(0, remainingSeconds - missedSeconds);
        
        // If timer would have completed during sleep
        if (remainingSeconds <= 0) {
          if (timer) {
            clearInterval(timer);
            timer = null;
          }
          self.postMessage({ type: 'complete' });
          return;
        }
        
        // Update the UI with the new time
        self.postMessage({
          type: 'tick',
          remainingSeconds: remainingSeconds
        });
      }
    }
  }
  
  // Update last tick time
  lastTickTime = Date.now();
}

self.onmessage = function(e) {
  const { type, data } = e.data;
  
  switch (type) {
    case 'start':
      if (timer) clearInterval(timer);
      remainingSeconds = data.seconds;
      startTime = Date.now();
      lastTickTime = startTime;
      isPaused = false;
      
      // Send initial tick
      self.postMessage({
        type: 'tick',
        remainingSeconds: remainingSeconds
      });
      
      timer = setInterval(() => {
        if (!isPaused) {
          // Check for timer accuracy/drift first
          checkTimerAccuracy();
          
          remainingSeconds--;
          
          self.postMessage({
            type: 'tick',
            remainingSeconds: remainingSeconds
          });
          
          if (remainingSeconds <= 0) {
            clearInterval(timer);
            timer = null;
            self.postMessage({ type: 'complete' });
          }
        }
      }, 1000);
      break;
      
    case 'pause':
      isPaused = true;
      break;
      
    case 'stop':
      if (timer) {
        clearInterval(timer);
        timer = null;
      }
      remainingSeconds = 0;
      startTime = null;
      lastTickTime = null;
      isPaused = false;
      break;
      
    case 'adjust':
      // Adjust the timer after app comes back from background
      remainingSeconds = data.seconds;
      lastTickTime = Date.now(); // Reset the tick time
      
      // Send updated time to UI
      self.postMessage({
        type: 'tick',
        remainingSeconds: remainingSeconds
      });
      
      // If we were paused, stay paused
      if (!isPaused && timer === null && remainingSeconds > 0) {
        // If timer was stopped but we need to restart it
        startTime = Date.now();
        
        timer = setInterval(() => {
          if (!isPaused) {
            // Check for timer accuracy/drift first
            checkTimerAccuracy();
            
            remainingSeconds--;
            
            self.postMessage({
              type: 'tick',
              remainingSeconds: remainingSeconds
            });
            
            if (remainingSeconds <= 0) {
              clearInterval(timer);
              timer = null;
              self.postMessage({ type: 'complete' });
            }
          }
        }, 1000);
      }
      break;
  }
};
