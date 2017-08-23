#!/bin/bash
# Run the container with the host port 4000 mapped to the published/exposed
# port 80 of the image
echo "Starting the container..."
container_id=$(docker run --rm --detach --publish 4000:80 friendlyhello)
# The container says that it is listening on http://0.0.0.0:80/ and that
# means that from host it is listening on http://localhost:80/
sleep 1
echo "Calling the application..."
curl --silent http://localhost:4000/
sleep 1
echo "... again ..."
curl --silent http://localhost:4000/
printf "\nStopping the container..."
docker stop $container_id
