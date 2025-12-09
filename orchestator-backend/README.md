# Orchestador (backend)
This is the middleware that connects with API's that offers different services.
## Instalation
1. First you have to create a virtual enviroment on the terminal and activate de virtual enviroment.
```bash
      python -m venv venv
      .\venv\Scripts\activate
```
2. You need to upgrade packages and install requirements of the proyect.
```bash
        python -m pip install --upgrade pip
        pip install -r requirements.txt
```
3. To run the orchestator.
```bash
        uvicorn app.main:app --reload
```
<strong>If you add new libraries</strong> to the project to save them
```bash
        pip freeze > requirements.txt
```
