const jwt = require('jsonwebtoken');

/**
 * Express middleware that verifies the JWT access token from the
 * Authorization: Bearer <token> header and attaches req.userId.
 *
 * Sends 401 on missing/invalid/expired tokens (the Flutter Dio interceptor
 * will try a token-refresh and retry).
 */
function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Missing or malformed authorization header.' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const payload = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
    req.userId = payload.sub || payload.userId;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Access token has expired.', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ message: 'Invalid access token.', code: 'TOKEN_INVALID' });
  }
}

module.exports = authenticate;
module.exports.authenticate = authenticate;
