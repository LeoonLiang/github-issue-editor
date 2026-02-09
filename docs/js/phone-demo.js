// 手机演示交互
document.addEventListener('DOMContentLoaded', () => {
    const phoneScreen = document.getElementById('phoneScreen');
    const indicators = document.querySelectorAll('.screen-indicator');

    // 切换屏幕的函数
    function navigateToScreen(screen) {
        // 添加淡出效果（iOS 风格）
        phoneScreen.style.opacity = '0';
        phoneScreen.style.transform = 'scale(0.98)';

        // 切换屏幕
        setTimeout(() => {
            phoneScreen.src = `mock-screens/${screen}.html`;

            // 更新指示器状态
            indicators.forEach(indicator => {
                if (indicator.dataset.screen === screen) {
                    indicator.classList.add('active');
                } else {
                    indicator.classList.remove('active');
                }
            });

            // 添加淡入效果
            setTimeout(() => {
                phoneScreen.style.opacity = '1';
                phoneScreen.style.transform = 'scale(1)';
            }, 30);
        }, 180);
    }

    // 监听来自 iframe 的导航消息
    window.addEventListener('message', (event) => {
        if (event.data.type === 'navigate') {
            navigateToScreen(event.data.screen);
        }
    });

    // 监听屏幕指示器点击
    indicators.forEach(indicator => {
        indicator.addEventListener('click', () => {
            const screen = indicator.dataset.screen;
            navigateToScreen(screen);
        });
    });

    // 添加过渡效果（使用 iOS 缓动曲线）
    phoneScreen.style.transition = 'opacity 0.18s cubic-bezier(0.4, 0, 0.2, 1), transform 0.18s cubic-bezier(0.4, 0, 0.2, 1)';
});
