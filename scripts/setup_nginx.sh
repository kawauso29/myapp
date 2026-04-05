#!/bin/bash
sudo cp ~/myapp/config/nginx/myapp.conf /etc/nginx/sites-available/myapp && sudo nginx -t && sudo systemctl reload nginx && echo "Nginx updated OK"
