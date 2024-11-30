# 🔑 Build Permission Management

Welcome to the **Build Permission Management** repository! This repository is used to handle requests for build permissions and removal of build permissions for specific users and packages.

---

## 📄 Issue Templates

This repository includes two issue templates to manage permissions:

1. **Request Build Permission**  
   Use this template to request build permissions for a specific package.

2. **Remove Build Permission**  
   Use this template to remove all build permissions for a specific user.

---

## 🔧 How to Create a Request

### 1. **Request Build Permission**
To request build permissions for a package:
1. Go to the **[Issues](../../issues)** tab of this repository.
2. Click on the **"New Issue"** button.
3. Select the **"🔑 Request Build Permission"** template.
4. Fill out the required fields:
   - **📧 Email Address**: Enter your email to receive updates about the request.
   - **📂 Select Package**: Choose the package for which you need build permissions.
   - **✍️ Reason for Request**: Provide a brief explanation of why you need build permissions.
   - **💬 Additional Notes**: Add any extra information (optional).
5. Submit your issue.

⚠️ **Important:** Do not change the issue title. The format should remain as:  
`[PBPR] Package Build Permission`.

---

### 2. **Remove Build Permission**
To remove build permissions for a user:
1. Go to the **[Issues](../../issues)** tab of this repository.
2. Click on the **"New Issue"** button.
3. Select the **"🗑️ Remove Build Permission"** template.
4. Fill out the required fields:
   - **👤 GitHub Username**: Enter the GitHub username of the user whose permissions you want to remove.
   - **✍️ Reason for Removal**: Provide a brief explanation of why the permissions should be removed.
5. Submit your issue.

⚠️ **Important:** Do not change the issue title. The format should remain as:  
`[PBPR] Remove permission`.

---

## 🛠️ Workflow Process

### For Build Permission Requests:
1. Once a request is submitted, our system will validate the information provided.
2. If valid, the request will be processed, and the requester will receive:
   - **An API Key**: Sent via email with instructions for usage.
3. If the request is invalid, a comment will be added to the issue with rejection details.

### For Removal Requests:
1. Once a request is submitted, our system will validate the information provided.
2. If valid, all build permissions for the specified user will be removed.
3. If the request is invalid, a comment will be added to the issue with rejection details.

---

## 🚀 Support

For any questions or additional assistance, feel free to create an issue using the **"General Inquiry"** template or contact our support team directly.

Thank you for using **Build Permission Management**! 😊
