let timer = null;
let startTime = null;
let remainingSeconds = 0;

self.onmessage = function(e) {
  const { type, data } = e.data;
  
  switch (type) {
    case 'start':
      if (timer) clearInterval(timer);
      remainingSeconds = data.seconds;
      startTime = Date.now();
      
      // Send initial tick
      self.postMessage({
        type: 'tick',
        remainingSeconds: remainingSeconds
      });
      
      timer = setInterval(() => {
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
      }, 1000);
      break;
      
    case 'pause':
      if (timer) {
        clearInterval(timer);
        timer = null;
      }
      break;
      
    case 'stop':
      if (timer) {
        clearInterval(timer);
        timer = null;
      }
      remainingSeconds = 0;
      startTime = null;
      break;
  }
};
