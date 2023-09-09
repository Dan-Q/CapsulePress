# CapsulePress

Opinionated Gemini/Spartan/Gopher server backended by a WordPress database. Use WordPress for content management, but publish for a simpler Internet.

![Illustration showing CapsulePress, whose logo is represented by a "WordPress-style" circle in light purple emblazoned with a spacecraft with the astrological sign for Gemini on it, taking posts from WordPress and publishing them via the gemini://, spartan:// and gopher:// protocols](https://github.com/Dan-Q/CapsulePress/assets/53293/e5ada698-32ff-4a0d-a48c-819cbb5c45cf)

## Requirements

- Ruby 3.x (tested most-thoroughly on 3.0.4)
- OpenSSL (if using Gemini)
- Superuser access, Authbind or similar (if running Spartan or Gopher on their default ports, which are in the privileged range)
- A WordPress instance

## Installation

1. Run `bundle` to install dependencies.
2. If using Gemini, generate a keypair with e.g. `mkdir -p keys && openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/CN=example.com" -keyout keys/key.pem -out keys/cert.pem`
3. Create `.env` (use the sample template below to help)
4. Run `ruby capsulepress.rb` to execute: you might like to set this up as a service; be aware that the default Spartan [300] and Gopher [70] ports are priviledged

### .env sample

A sample `.env` file you can take and adapt:

```
# Specify which protocols will be used:
USE_GEMINI=true
USE_SPARTAN=true
USE_GOPHER=true

# If you want to run on unusual TCP ports etc., specify them:
GEMINI_PORT=1965
GEMINI_HOST=0.0.0.0
SPARTAN_PORT=300
SPARTAN_HOST=0.0.0.0
SPARTAN_MAX_CONNECTIONS=4
GOPHER_HOST=0.0.0.0
GOPHER_PORT=70
GOPHER_DOMAIN=example.com

# If you're using Gemini, you'll need to provide a keypair:
GEMINI_CERT_PATH=keys/cert.pem
GEMINI_KEY_PATH=keys/key.pem

# Credentials for your WordPress instance's MySQL database:
# (you might like to use a read-only/limited user, for additional safety)
DB_HOST=localhost
DB_USER=username
DB_PASS=password
DB_NAME=database

# Domain name of your WordPress instance (used for reverse-engineering internal link URLs):
DOMAIN=example.com

# Path to your WordPress instance's /wp-content/uploads/ directory:
WP_CONTENT_UPLOADS_DIR=/var/www/wordpress/wp-content/uploads/

```

### Running on priviledged ports

`authbind` can grant a user access to priviledged ports, which can be useful if you run your service as a non-root user (and you should):

```bash
sudo touch /etc/authbind/byport/70
sudo chown -R yourusername:root /etc/authbind/byport/70
sudo chmod -R 770 /etc/authbind/byport/70
sudo touch /etc/authbind/byport/300
sudo chown -R yourusername:root /etc/authbind/byport/300
sudo chmod -R 770 /etc/authbind/byport/300
```

### Running as a service

You could perhaps use the following SystemD configuration file, `/etc/systemd/system/capsulepress.service`:

```
# CapsulePress
[Unit]
Description=CapsulePress

[Service]
User=yourusername
Group=users
WorkingDirectory=/var/capsulepress
Restart=always
ExecStart=/usr/bin/authbind --deep /home/yourusername/.rvm/gems/ruby-3.0.4/wrappers/ruby capsulepress.rb

[Install]
WantedBy=multi-user.target
```

## Copyright and License

Copyright Dan Q 2023. MIT-licensed. You know the drill by now.
