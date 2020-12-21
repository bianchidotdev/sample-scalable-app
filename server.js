'use strict';

const express = require('express');

// Constants
const PORT = 3000;
const HOST = '0.0.0.0';

// App
const app = express();
app.get('/', (req, res) => {
  res.send('Hello world\n');
});

app.get('/expensive', (req, res) => {
  let x = 0.0001;
  for (let i = 0; i <= 1000000; i++) {
    x += Math.sqrt(x);
  }
  res.send('OK!\n');
});

app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);
