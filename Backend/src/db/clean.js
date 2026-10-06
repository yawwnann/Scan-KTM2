const { clearDatabase } = require('./clear');

if (require.main === module) {
  clearDatabase()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = { clearDatabase };
