let timer = null;
let startTime = null;
let remainingSeconds = 0;
let isPaused = false;

self.onmessage = function(e) {
  const { type, data } = e.data;
  
  switch (type) {
    case 'start':
      if (timer) clearInterval(timer);
      remainingSeconds = data.seconds;
      startTime = Date.now();
      isPaused = false;
      
      // Send initial tick
      self.postMessage({
        type: 'tick',
        remainingSeconds: remainingSeconds
      });
      
      timer = setInterval(() => {
        if (!isPaused) {
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
      isPaused = false;
      break;
      
    case 'adjust':
      // Adjust the timer after app comes back from background
      remainingSeconds = data.seconds;
      
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
