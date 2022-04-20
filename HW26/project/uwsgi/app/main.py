from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Hello from Flask app\n'

if __name__ == '__main__':
    # Only for debugging while developing    
    app.run(debug=True, host='0.0.0.0')

