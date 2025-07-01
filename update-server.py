VERSION = "1.1.1"  # Update this when you release a new version

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI()

# Enable CORS (optional, configure origins as needed)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust for production
    allow_credentials=True,
    allow_methods=["GET"],
    allow_headers=["*"],
)

UPDATE_FILE_PATH = "SuperMenu.zip"  # Path to your update file

@app.get("/api/update")
async def get_update():
    if not os.path.isfile(UPDATE_FILE_PATH):
        raise HTTPException(status_code=404, detail="Update file not found.")
    return FileResponse(UPDATE_FILE_PATH, media_type='application/zip', filename=os.path.basename(UPDATE_FILE_PATH))


# Version endpoint
@app.get("/api/version")
async def get_version():
    return VERSION


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)