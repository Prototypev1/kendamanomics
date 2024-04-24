import 'package:flutter/material.dart';
import 'package:kendamanomics_mobile/extensions/custom_colors.dart';
import 'package:kendamanomics_mobile/helpers/custom_page_view_scroll_physics.dart';
import 'package:kendamanomics_mobile/providers/register_provider.dart';
import 'package:provider/provider.dart';

class RegisterShell extends StatelessWidget {
  static const pageName = 'register';
  const RegisterShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: CustomColors.of(context).backgroundColor,
      body: SafeArea(
        child: ChangeNotifierProvider(
          create: (context) => RegisterProvider(),
          builder: (context, child) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PageView.builder(
                  physics: const CustomPageViewScrollPhysics(),
                  itemCount: context.read<RegisterProvider>().pages.length,
                  onPageChanged: (value) {
                    context.read<RegisterProvider>().setCurrentPage(value);
                    if (value != 3) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }
                  },
                  itemBuilder: (context, index) {
                    return context.read<RegisterProvider>().pages[index];
                  },
                ),
              ),
              Selector<RegisterProvider, int>(
                selector: (_, provider) => provider.currentPage,
                builder: (context, currentPage, child) => buildIndicator(currentPage, context),
              ),
              const SizedBox(height: 8.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildIndicator(int currentPage, BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.linear,
      padding: EdgeInsets.only(left: MediaQuery.of(context).size.width / 4.0 * currentPage),
      child: Container(
        height: 4.0,
        width: MediaQuery.of(context).size.width / 4.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(80.0),
          shape: BoxShape.rectangle,
          color: CustomColors.of(context).activeIndicatorColor,
        ),
      ),
    );
  }
}
