import bcrypt


def hash_password(password):
        hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
        return hashed_password.decode('utf-8')


def check_password(input_password, stored_password):
    return bcrypt.checkpw(input_password.encode('utf-8'), stored_password.encode('utf-8'))