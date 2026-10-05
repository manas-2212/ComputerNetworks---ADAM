const express = require("express");

const app = express();

const PORT = 3002;

// Root endpoint
app.get("/", (req, res) => {
  res.set("X-Backend", "B");

  res.json({
    backend: "B",
    message: "Backend B is running",
    port: PORT,
  });
});

// Status endpoint
app.get("/api/status", (req, res) => {
  res.set("X-Backend", "B");
  res.set("Cache-Control", "max-age=60");

  res.json({
    backend: "B",
    status: "ok",
    server: "Darain",
    timestamp: new Date().toISOString(),
  });
});

// Start server
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Backend B running on http://0.0.0.0:${PORT}`);
});
