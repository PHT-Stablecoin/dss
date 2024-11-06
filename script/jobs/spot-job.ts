
import process from 'node:process';

const main = async () {
    throw 'unimplemented'
}

main()
    .catch(e => {
        console.error(e);
        process.exit(1);
    })
    .then(process.exit(0))