# Use the latest Foundry image as the base
FROM ghcr.io/foundry-rs/foundry AS foundry

# Set the working directory for Foundry
WORKDIR /app

# Copy the Solidity source code into the container
COPY . .

# Build and test the Solidity code
RUN forge build
RUN forge test

# Use Node.js as a secondary stage for backend functionality
FROM node:iron AS node

# Set the working directory for Node.js
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to install dependencies
COPY package*.json ./

# Install Node.js dependencies
RUN npm install

# Copy the rest of the application code into the container
COPY . .

# Set environment variables for Forge (if needed)
ENV FORGE_CLIENT_ID=default
ENV FORGE_CLIENT_SECRET=default

# Expose the port on which your Node.js app will run
EXPOSE 3000

# Command to run your Node.js application
CMD [ "npm", "start" ]
